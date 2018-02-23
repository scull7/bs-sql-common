
external make_error : string -> exn = "Error"
[@@bs.new]

external exn_code : exn -> string Js.Nullable.t = "code"
[@@bs.get]

external exn_errno : exn -> string Js.Nullable.t = "errno"
[@@bs.get]

external exn_sql_state : exn -> string Js.Nullable.t = "sqlState"
[@@bs.get]

external exn_sql_message : exn -> string Js.Nullable.t = "sqlMessage"
[@@bs.get]
