val query :
  (
    sql:string ->
    ?params:'a ->
    (
      [<
        `Error of 'b
      | `Select of Js.Json.t array * MySql2.meta
      ] -> 'c
    ) ->
    'd
  ) ->
  ?batch_size:int ->
  sql: string ->
  params:[`Positional of Js.Json.t array] ->
  ([> `Error of 'b | `Select of Js.Json.t array * MySql2.meta] -> 'c) ->
  unit
