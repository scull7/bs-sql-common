module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable): sig

  module Connection: sig
    type t

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

  module Params : sig
    val named : Js.Json.t -> Driver.Params.t

    val positional : Js.Json.t -> Driver.Params.t
  end

  module Response: sig
    module Mutation: sig
      val insertId : Driver.Mutation.t -> Id.t option

      val affectedRows: Driver.Mutation.t -> int
    end

    module Select: sig
      module Meta : sig
        val schema : Driver.Select.Meta.t -> string

        val name : Driver.Select.Meta.t -> string

        val table : Driver.Select.Meta.t -> string
      end

      val meta : Driver.Select.t -> Driver.Select.Meta.t array

      val concat : Driver.Select.t -> Driver.Select.t -> Driver.Select.t

      val count : Driver.Select.t -> int

      val flatMapWithMeta :
        Driver.Select.t ->
        (Js.Json.t -> Driver.Select.Meta.t array -> 'a) ->
        'a array

      val flatMap : Driver.Select.t -> (Js.Json.t -> 'a) -> 'a array

      val rows : Driver.Select.t -> Js.Json.t array
    end
  end

  val mutate :
    db:Driver.Connection.t ->
    sql:string ->
    ?params:Driver.Params.t ->
    ((Driver.Mutation.t, exn) Belt.Result.t -> unit) ->
    unit

  val query :
    db:Driver.Connection.t ->
    sql:string ->
    ?params:Driver.Params.t ->
    ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
    unit

  module Batch: sig
    val mutate :
      db:Driver.Connection.t ->
      ?batch_size:int ->
      table:string ->
      columns: string array ->
      rows:Js.Json.t array ->
      ((int, exn) Belt.Result.t -> unit) ->
      unit
  
    val query :
      db:Driver.Connection.t ->
      ?batch_size:int ->
      sql:string ->
      params:[`Positional of Js.Json.t array ] ->
      ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
      unit
  end

  module Promise: sig

    val mutate :
      db:Driver.Connection.t ->
      ?params:Driver.Params.t ->
      sql:string ->
      Driver.Mutation.t Js.Promise.t

    val query :
      db:Driver.Connection.t ->
      ?params:Driver.Params.t ->
      sql:string ->
      Driver.Select.t Js.Promise.t

    module Batch: sig

      val mutate :
        db:Driver.Connection.t ->
        ?batch_size:int ->
        table:string ->
        columns:string array ->
        rows:Js.Json.t array ->
        unit ->
        int Js.Promise.t

      val query :
        db:Driver.Connection.t ->
        ?batch_size:int ->
        sql:string ->
        params:[`Positional of Js.Json.t array ] ->
        unit ->
        Driver.Select.t Js.Promise.t
    end
  end
end
