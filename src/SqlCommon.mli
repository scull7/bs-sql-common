module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable): sig

  module Connection: sig
    type t = Driver.Connection.t

    val close: t -> unit

    val connect :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit -> t

  end

  module Id: sig
    type t = Driver.Id.t

    val fromJson : Js.Json.t -> t

    val toJson : t -> Js.Json.t

    val toString : t -> string
  end

  module Params : sig
    type t = Driver.Params.t

    val named : Js.Json.t -> t

    val positional : Js.Json.t -> t
  end

  module Response: sig
    module Mutation: sig
      type t = Driver.Mutation.t

      val insertId : t -> Id.t option

      val affectedRows: t -> int
    end

    module Select: sig
      type t = Driver.Select.t

      module Meta : sig
        type t = Driver.Select.Meta.t

        val schema : t -> string

        val name : t -> string

        val table : t -> string
      end

      val meta :t -> Meta.t array

      val concat : t -> t -> t

      val count : t -> int

      val flatMapWithMeta :
        t ->
        (Js.Json.t -> Meta.t array -> 'a) ->
        'a array

      val flatMap : t -> (Js.Json.t -> 'a) -> 'a array

      val rows : t -> Js.Json.t array
    end
  end

  val mutate :
    db:Connection.t ->
    sql:string ->
    ?params:Params.t ->
    ((Response.Mutation.t, exn) Belt.Result.t -> unit) ->
    unit

  val query :
    db:Connection.t ->
    sql:string ->
    ?params:Params.t ->
    ((Response.Select.t, exn) Belt.Result.t -> unit) ->
    unit

  module Batch: sig
    val mutate :
      db:Connection.t ->
      ?batch_size:int ->
      table:string ->
      columns: string array ->
      encoder:('a -> Js.Json.t array) ->
      rows:'a array ->
      ((int, exn) Belt.Result.t -> unit) ->
      unit
  
    val query :
      db:Connection.t ->
      ?batch_size:int ->
      sql:string ->
      params:[`Positional of Js.Json.t array ] ->
      ((Response.Select.t, exn) Belt.Result.t -> unit) ->
      unit
  end

  module Promise: sig

    val mutate :
      db:Connection.t ->
      ?params:Params.t ->
      sql:string ->
      Response.Mutation.t Js.Promise.t

    val query :
      db:Connection.t ->
      ?params:Params.t ->
      sql:string ->
      Response.Select.t Js.Promise.t

    module Batch: sig

      val mutate :
        db:Connection.t ->
        ?batch_size:int ->
        table:string ->
        columns:string array ->
        encoder:('a -> Js.Json.t array) ->
        rows:'a array ->
        unit ->
        int Js.Promise.t

      val query :
        db:Connection.t ->
        ?batch_size:int ->
        sql:string ->
        params:[`Positional of Js.Json.t array ] ->
        unit ->
        Response.Select.t Js.Promise.t
    end
  end
end
