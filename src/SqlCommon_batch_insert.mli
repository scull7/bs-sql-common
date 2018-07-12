module Make(Driver: SqlCommon_queryable.Queryable): sig

val start :
  driver:(
    sql:string ->
    (
      [<
      | `Error of exn
      | `Mutation of Driver.Mutation.t
      ] -> unit
    ) ->
    unit
  ) ->
  ?batch_size:int ->
  table:string ->
  columns: string array ->
  rows: 'b array ->
  ((int, exn) Belt.Result.t -> unit) ->
  unit
end
