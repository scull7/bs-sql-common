
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
    val run :
      Driver.Connection.t ->
      ?params: Driver.Params.t ->
      sql: string ->
      Driver.Select.t Js.Promise.t
  end

  module Mutate : sig
    val run :
      Driver.Connection.t ->
      ?params: Driver.Params.t ->
      sql: string ->
      Driver.Mutation.t Js.Promise.t
  end
end
