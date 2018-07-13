module Make(Driver: SqlCommon_queryable.Queryable): sig

val start :
  driver:(
    sql:string ->
    ((Driver.Mutation.t, exn) Belt.Result.t -> unit) ->
    unit
  ) ->
  ?batch_size:int ->
  table:string ->
  columns: string array ->
  rows: Js.Json.t array ->
  ((int, exn) Belt.Result.t -> unit) ->
  unit

end
