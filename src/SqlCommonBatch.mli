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


(* val query :
  (
    sql:string ->
    ?params:'a ->
    (
      [<
        `Error of 'b
      | `Select of Js.Json.t array * Js.Json.t
      ] -> 'c
    ) ->
    'd
  ) ->
  ?batch_size:int ->
  sql_string: string ->
  params_array: 'e Js.Array.t ->

  ([> `Error of 'b | `Select of Js.Json.t array * Js.Json.t] -> 'c) ->
  unit
 *)

(* val query :
  (
    sql:string ->
    ?params:'a ->
    (
      [<
        `Error of 'b
      | `Select of Js.Json.t array * Js.Json.t
      ] -> 'c
    ) ->
    'd
  ) ->
  ?batch_size:int ->
  sql_string: string ->
  params_array: 'b Js.Array.t ->

  ([> `Error of exn | `Select of Js.Json.t array * Js.Json.t] -> unit) ->
  unit *)
