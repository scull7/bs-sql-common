[@bs.new]
external make_error: string => exn = "Error";

[@bs.get]
external exn_code: exn => Js.Nullable.t(string) = "code";

[@bs.get]
external exn_errno: exn => Js.Nullable.t(string) = "errno";

[@bs.get]
external exn_sql_state: exn => Js.Nullable.t(string) = "sqlState";

[@bs.get]
external exn_sql_message: exn => Js.Nullable.t(string) = "sqlMessage";
