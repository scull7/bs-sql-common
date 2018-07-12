module Make (Driver: SqlCommon_queryable.Queryable) : sig
  val close : Driver.Connection.t -> unit

  val connect :
    ?host:string ->
    ?port:int ->
    ?user:string ->
    ?password:string ->
    ?database:string ->
    unit -> Driver.Connection.t

  module Select : sig
    val query :
      Driver.Connection.t ->
      ?params: Driver.Params.t ->
      sql: string ->
      ([ | `Select of Driver.Select.t  | `Error of exn ] -> unit) ->
      unit
  end

  module Mutate : sig
    val run :
      Driver.Connection.t ->
      ?params: Driver.Params.t ->
      sql: string ->
      ([ | `Mutation of Driver.Mutation.t  | `Error of exn ] -> unit) ->
      unit
  end
end
