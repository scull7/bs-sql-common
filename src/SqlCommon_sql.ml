
let contains_in sql = Js.Re.test sql [%re "/\\bin\\b/i"]

external format :
  string ->
  'a Js.Array.t ->
  string
  = "format" [@@bs.module "sqlstring"]
