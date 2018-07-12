module Make(Driver: SqlCommon_queryable.Queryable): sig
  val start :
    driver:(
      sql:string ->
      (
        [<
        | `Error of exn
        | `Select of Driver.Select.t
        ] -> unit
      ) ->
      unit
    ) ->
    ?batch_size:int ->
    sql: string ->
    params: [< `Positional of Js.Json.t ] ->
    ( [ | `Error of exn | `Select of Driver.Select.t ] -> unit) ->
    unit
end
