module Make(Driver: SqlCommon_queryable.Queryable): sig
  val start :
    driver:(
      sql:string ->
      ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
      unit
    ) ->
    ?batch_size:int ->
    sql: string ->
    params: [`Positional of Js.Json.t array ] ->
    ((Driver.Select.t, exn) Belt.Result.t -> unit) ->
    unit
end
