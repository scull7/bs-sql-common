module Make (Driver: SqlCommon_queryable.Queryable) : sig

  module Select : sig
    val query :
      Driver.Connection.t ->
      ?params: Driver.Params.t ->
      sql: string ->
      ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
      unit
  end

  module Mutate : sig
    val run :
      Driver.Connection.t ->
      ?params: Driver.Params.t ->
      sql: string ->
      ((Driver.Mutation.t, exn) Belt.Result.t -> unit) ->
      unit
  end
end
