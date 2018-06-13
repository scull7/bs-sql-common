val query :
  (
    sql:string ->
    ?params:'a ->
    (
      [<
        `Error of 'b
      | `Select of Js.Json.t array * MySql2.meta
      ] -> unit
    ) ->
    'd
  ) ->
  ?batch_size:int ->
  sql: string ->
  params:[`Positional of Js.Json.t] ->
  ([> `Error of 'b | `Select of Js.Json.t array * MySql2.meta] -> unit) ->
  unit


val valid_query_params: [`Positional of Js.Json.t] -> bool
