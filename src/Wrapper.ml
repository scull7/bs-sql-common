type sql = string

type conn = Connection.t

type node_style_err = exn Js.Nullable.t
type result_data = Js.Json.t
type result_meta = Result.column_data Js.Array.t Js.Nullable.t
type query_cb = node_style_err -> result_data -> result_meta -> unit


(* https://github.com/glennsl/bucklescript-cookbook#bind-to-a-higher-order-function-that-takes-a-function-accepting-an-argument-of-several-different-types-an-untagged-union *)
module Query = struct
  type 'a named_params = <
    sql: sql;
    values: 'a Js.t Js.Nullable.t;
    namedPlaceholders: Js.boolean;
  > Js.t

  type 'a unnamed_params = <
    sql: sql;
    values: 'a Js.Array.t Js.Nullable.t;
    namedPlaceholders: Js.boolean;
  > Js.t

  external raw : conn -> sql -> query_cb -> unit = "query"
  [@@bs.send]
  external execute : conn -> 'a unnamed_params -> query_cb -> unit = "execute"
  [@@bs.send]
  external execute_named : conn -> 'a named_params -> query_cb -> unit
  = "execute"
  [@@bs.send]

  external makeNamed :
    sql:string ->
    values: 'a Js.t Js.Nullable.t ->
    namedPlaceholders: Js.boolean ->
    unit ->
    'a named_params = "" [@@bs.obj]

  external makeUnnamed :
    sql:string ->
    values: 'a Js.Array.t Js.Nullable.t ->
    namedPlaceholders: Js.boolean ->
    unit ->
    'a unnamed_params = "" [@@bs.obj]
end


let parse results fields =
  match Result.parse results fields with
    | ResultMutation m -> Response.Mutation m
    | ResultSelect s -> Response.Select s

let transform err results fields =
  match Js.Nullable.to_opt err with
    | None -> parse results fields
    | Some e -> Response.Error e

let handler cb err results fields = cb (transform err results fields)

let query conn sql cb = Query.raw conn sql (handler cb)

let execute conn sql params cb =
  match params with
  | `ParamsNamed p ->
    let options =
      Query.makeNamed ~sql ~values:p ~namedPlaceholders:Js.true_ ()
    in
      Query.execute_named conn options (handler cb)
  | `ParamsUnnamed p ->
    let options =
      Query.makeUnnamed ~sql ~values:p ~namedPlaceholders:Js.false_ ()
    in
      Query.execute conn options (handler cb)
