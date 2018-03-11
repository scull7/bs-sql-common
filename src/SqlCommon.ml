module type Queryable = sig
  type connection
  type meta
  type rows = Js.Json.t array

  type params =
    [ `Named of Js.Json.t
    | `Positional of Js.Json.t
    ] option

  type callback =
    [ `Error of exn
    | `Mutation of int * int
    | `Select of rows * meta
    ] ->
    unit

  val close : connection -> unit

  val connect :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit -> connection

  val execute : connection -> string -> params -> callback -> unit
end

module type Make_store = sig
  type connection
  type error
  type params =
    [ `Named of Js.Json.t
    | `Positional of Js.Json.t array
    ] option

  val close : connection -> unit

  val connect :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit -> connection

  val query :
    connection ->
    sql:string ->
    ?params:params ->
    ([`Error of exn | `Select of Js.Json.t * Js.Json.t] -> unit)
    -> unit
  val mutate :
    connection ->
    sql:string ->
    ?params:params ->
    ([`Error of exn | `Mutation of int * int] -> unit)
    -> unit
  val mutate_batch :
    connection ->
    ?batch_size:int ->
    table:string ->
    columns:Js.Json.t ->
    rows:Js.Json.t ->
    ([> `Error of exn | `Mutation of int * int] -> unit) ->
    unit

end

module Make_sql(Driver: Queryable) = struct

  type connection = Driver.connection
  type sql = string
  type params = Js.Json.t

  let close = Driver.close
  let connect = Driver.connect

  let invalid_response_mutation = Failure {|
      SqlCommonError - ERR_UNEXPECTED_MUTATION (99999)
      Invalid Response: Expected Select got Mutation
    |}

  let invalid_response_select = Failure {|
    SqlCommonError - ERR_UNEXPECTED_MUTATION (99999)
    Invalid Response: Expected Mutation got Select
  |}

  let query conn ~sql ?params cb =
    Driver.execute conn sql params (fun res ->
      match res with
      | `Select (data, meta) -> cb (`Select (data, meta))
      | `Mutation _ -> cb (`Error invalid_response_mutation)
      | `Error e -> cb (`Error e)
    )

  let mutate conn ~sql ?params cb =
    Driver.execute conn sql params (fun res ->
      match res with
      | `Select _ -> cb (`Error invalid_response_select)
      | `Mutation (changed, last_id)-> cb (`Mutation (changed, last_id))
      | `Error e -> cb (`Error e)
    )

  let mutate_batch conn ?batch_size ~table ~columns ~rows cb =
    SqlCommonBatch.insert (mutate conn) ?batch_size ~table ~columns ~rows cb

  module Promise : sig

    val query :
      connection ->
      sql:string ->
      ?params:[ `Named of Js.Json.t | `Positional of Js.Json.t ] ->
      unit ->
      (Driver.rows * Driver.meta) Js.Promise.t

    val mutate :
      connection ->
      sql:string ->
      ?params:[ `Named of Js.Json.t | `Positional of Js.Json.t ] ->
      unit ->
      (int * int) Js.Promise.t

    val mutate_batch :
      connection ->
      ?batch_size:int ->
      table:string ->
      columns:'a array ->
      rows:'a array ->
      (int * int) Js.Promise.t
  end = struct

    let query conn ~sql ?params _ =
      Js.Promise.make (fun ~resolve ~reject ->
        query conn ~sql ?params (fun res ->
          match res with
          | `Error e -> reject e [@bs]
          | `Select (rows, meta) -> resolve (rows, meta) [@bs]
        )
      )

    let mutate conn ~sql ?params _ =
      Js.Promise.make (fun ~resolve ~reject ->
        mutate conn ~sql ?params (fun res ->
          match res with
          | `Error e -> reject e [@bs]
          | `Mutation (count, id) -> resolve (count, id) [@bs]
        )
      )

    let mutate_batch conn ?batch_size ~table ~columns ~rows =
      Js.Promise.make (fun ~resolve ~reject ->
        mutate_batch conn ?batch_size ~table ~columns ~rows (fun res ->
          match res with
          | `Error e -> reject e [@bs]
          | `Mutation (count, id) -> resolve (count, id) [@bs]
        )
      )
  end
end
