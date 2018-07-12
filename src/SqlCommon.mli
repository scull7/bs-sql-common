module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable): sig

  module Connection: sig
    val close: Driver.Connection.t -> unit

    val connect :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit -> Driver.Connection.t

  end

  module Id: sig
    type t = Driver.Id.t

    val fromJson : Js.Json.t -> Driver.Id.t

    val toJson : Driver.Id.t -> Js.Json.t

    val toString : Driver.Id.t -> string
  end

  module Response: sig
    module Mutation: sig
      val insertId : Driver.Mutation.t -> Id.t option

      val affectedRows: Driver.Mutation.t -> int
    end

    module Select: sig
    end
  end

  val mutate :
    Driver.Connection.t ->
    ?params:Driver.Params.t ->
    sql:string ->
    ((Driver.Mutation.t, exn) Belt.Result.t -> unit) ->
    unit

  val query :
    Driver.Connection.t ->
    ?params:Driver.Params.t ->
    sql:string ->
    ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
    unit

  module Batch: sig
    module Mutate: sig
      val start :
        db:Driver.Connection.t ->
        ?batch_size:int ->
        table:string ->
        columns: string array ->
        rows:Js.Json.t array ->
        ((int, exn) Belt.Result.t -> unit) ->
        unit
    end

    module Query: sig
      val start :
        db:Driver.Connection.t ->
        ?batch_size:int ->
        sql:string ->
        params:[`Positional of Js.Json.t array ] ->
        ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
        unit
    end
  end
end
