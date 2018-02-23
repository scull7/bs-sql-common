

module Mutation = struct
  type t = {
    affected_rows: int;
    insert_id: int option;
    info: string option;
    server_status: int option;
    warning_status: int;
    changed_rows: int;
  }

  let andThenClassify f = function
    | Some x -> f (Js.Json.classify x)
    | None -> None

  let parse_int_default x maybe_json =
    match maybe_json with
    | None -> x
    | Some v ->
      match Js.Json.classify v with
      | Js.Json.JSONNumber n -> (int_of_float n)
      | Js.Json.JSONNull -> x
      | _ -> failwith "parse_int_unexpected_value"

  let parse_int_maybe = andThenClassify (fun x ->
    match x with
    | Js.Json.JSONNumber 0.0 -> None
    | Js.Json.JSONNumber n -> Some (int_of_float n)
    | Js.Json.JSONNull -> None
    | _ -> failwith "parse_int_maybe_unexecpted_value"
    )

  let parse_string_maybe = andThenClassify (fun x ->
    match x with
    | Js.Json.JSONString "" -> None
    | Js.Json.JSONString s -> Some s
    | _ -> failwith "parse_string_maybe_unexpected_value"
    )

  let parse m = {
    affected_rows = parse_int_default 0 (Js.Dict.get m "affectedRows");
    changed_rows = parse_int_default 0 (Js.Dict.get m "changedRows");
    info = parse_string_maybe (Js.Dict.get m "info");
    insert_id = parse_int_maybe (Js.Dict.get m "insertId");
    server_status = parse_int_maybe (Js.Dict.get m "serverStatus");
    warning_status = parse_int_default 0 (Js.Dict.get m "warningStatus");
  }
end

module Select = struct
  type column_data = {
    catalog: string;
    schema: string;
    name: string;
    orgName: string;
    table: string;
    orgTable: string;
    characterSet: int;
    columnLength: int;
    columnType: int;
    flags: int;
    decimals: int
  }

  type t = {
    rows: Js.Json.t Js.Array.t;
    fields: column_data Js.Array.t;
  }

  let getRows { rows = r; _ } = r

  let parse s fields = {
    rows = s;
    fields = fields;
  }
end

type t =
  | ResultMutation of Mutation.t
  | ResultSelect of Select.t

let assert_fields fields json =
  match Js.Nullable.to_opt(fields) with
  | None -> failwith "invalid_driver_result_no_column_data"
  | Some f -> ResultSelect (Select.parse json f)

let parse json fields =
  match Js.Json.classify json with
    | Js.Json.JSONObject m -> (ResultMutation (Mutation.parse m))
    | Js.Json.JSONArray s -> assert_fields fields s
    | _ -> failwith "invalid_driver_result"
