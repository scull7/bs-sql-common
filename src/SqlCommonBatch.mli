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
