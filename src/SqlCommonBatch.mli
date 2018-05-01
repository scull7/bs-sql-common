val insert :
  (
    sql:string ->
    ?params:'a ->
    (
      [<
        `Error of exn
      | `Mutation of int * int
      ] -> unit
    ) ->
    unit
  ) ->
  ?batch_size:int ->
  table:string ->
  columns:'b array ->
  rows: 'b array ->
  ([> `Error of exn | `Mutation of int * int] -> unit) ->
  unit


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
  params:[`Positional of Js.Json.t] option ->
  ([> `Error of 'b | `Select of Js.Json.t array * MySql2.meta] -> 'c) ->
  unit
