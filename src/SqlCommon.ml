module type Queryable = sig
  type t
  type meta
  type rows = Js.Json.t array

  type params = [ `Named of Js.Json.t | `Anonymous of Js.Json.t ] option

  type callback = exn Js.Nullable.t -> Js.Json.t -> Js.Json.t array -> unit

  val close : t -> unit

  val parse_response :
    Js.Json.t->
    Js.Json.t array ->
    [> `Error of exn | `Mutation of int * int | `Select of rows * meta ]

  val execute : t -> string -> params -> callback -> unit
end

module type Make_store = sig
  type t
  type connection
  type params = [ `Named of Js.Json.t | `Anonymous of Js.Json.t array ] option

  val close : connection -> unit

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

module Make_store(Connection: Queryable) = struct

  type connection = Connection.t
  type sql = string
  type params = Js.Json.t

  let close conn = Connection.close conn

  let error_or error success err data meta =
    match (Js.Nullable.to_opt err) with
    | Some e -> error (`Error e)
    | None -> success (Connection.parse_response data meta)

  let query conn ~sql ?params cb =
    let success = (fun res ->
      match res with
      | `Select (data, meta) -> cb (`Select (data, meta))
      | `Mutation _ -> cb (`Error (Failure "invalid_response_mutation"))
      | `Error e -> cb (`Error e)
    )
    in
    Connection.execute conn sql params (error_or cb success)

  let mutate conn ~sql ?params cb =
    let success = (fun res ->
      match res with
      | `Select _ -> cb (`Error (Failure "invalid_response_select"))
      | `Mutation (changed, last_id)-> cb (`Mutation (changed, last_id))
      | `Error e -> cb (`Error e)
    )
    in
    Connection.execute conn sql params (error_or cb success)

  let mutate_batch conn ?batch_size ~table ~columns ~rows cb =
    SqlCommonBatch.insert (mutate conn) ?batch_size ~table ~columns ~rows cb

  module Promise : sig

    val query :
      connection ->
      sql:string ->
      ?params:[ `Named of Js.Json.t | `Anonymous of Js.Json.t ] ->
      unit ->
      (Connection.rows * Connection.meta) Js.Promise.t

    val mutate :
      connection ->
      sql:string ->
      ?params:[ `Named of Js.Json.t | `Anonymous of Js.Json.t ] ->
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
