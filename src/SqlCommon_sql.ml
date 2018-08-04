let commentsRe = [%re {|/(\/\*[\s\S]*?\*\/)|([^#:]|^)#.*$|(COMMENT ".*(.*)")/gmi|}]
let inRe = [%re "/\\bin\\b/i"]

let contains_in sql = 
  Js.String.replaceByRe commentsRe "" sql
    |> Js.String.trim
    |. Js.Re.test inRe

external format :
  string ->
  'a Js.Array.t ->
  string
  = "format" [@@bs.module "sqlstring"]