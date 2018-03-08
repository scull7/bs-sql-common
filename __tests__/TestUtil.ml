(*
  This needs to be imported from bs-mysql2, need to add bs-mysql2 as a
  dev dependency.
*)
module ResultMeta = struct
  type t = {
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

  let decode json = Json.Decode.({
    catalog = json |> field "catalog" string;
    schema = json |> field "schema" string;
    name = json |> field "name" string;
    orgName = json |> field "orgName" string;
    table = json |> field "table" string;
    orgTable = json |> field "orgTable" string;
    characterSet = json |> field "characterSet" int;
    columnLength = json |> field "columnLength" int;
    columnType = json |> field "columnType" int;
    flags = json |> field "flags" int;
    decimals = json |> field "decimals" int;
  })
end

module Result : sig
  type meta

  val parse :
    Js.Json.t ->
    Js.Json.t array ->
    [> `Error of exn
    | `Mutation of int * int
    | `Select of Js.Json.t array * meta
    ]

end = struct
  type meta = ResultMeta.t array

  let mutation json = Json.Decode.(
    let changes = json |> field "affectedRows" (withDefault 0 int) in
    let last_id = json |> field "insertId" (withDefault 0 int) in
    `Mutation (changes, last_id)
  )

  let select rows meta = `Select (rows, (Belt_Array.map meta ResultMeta.decode ))

  let parse json meta =
    match Js.Json.classify json with
    | Js.Json.JSONObject _ -> mutation json
    | Js.Json.JSONArray rows -> select rows meta
    | _ -> `Error (Failure "invalid_driver_result")
end

module Options = struct
  type t = <
    sql: string;
    values: Js.Json.t Js.Nullable.t;
    namedPlaceholders: Js.boolean;
  > Js.t

  let make sql values is_named =
    [%bs.obj { sql; values; namedPlaceholders = is_named; }]

  let from_params sql params =
    match params with
    | None -> make sql Js.Nullable.null Js.false_
    | Some p -> match p with
      | `Named json -> make sql (Js.Nullable.return json) Js.true_
      | `Anonymous json -> make sql (Js.Nullable.return json) Js.false_

end

module Connection : sig
  type t
  type callback = exn Js.Nullable.t -> Js.Json.t -> Js.Json.t array -> unit
  type meta = Result.meta
  type params = [ `Named of Js.Json.t | `Anonymous of Js.Json.t ] option
  type rows = Js.Json.t array

  val parse_response :
    Js.Json.t ->
    Js.Json.t array ->
    [> `Error of exn | `Mutation of int * int | `Select of rows * meta ]

  val make :
    ?host:string ->
    ?port:int ->
    ?user:string ->
    ?password:string ->
    ?database:string ->
    unit ->
    t

  val execute: t -> string -> params -> callback -> unit

  val close : t -> unit

end = struct
  type t
  type callback = exn Js.Nullable.t -> Js.Json.t -> Js.Json.t array -> unit
  type meta = Result.meta
  type params = [ `Named of Js.Json.t | `Anonymous of Js.Json.t ] option
  type rows = Js.Json.t array

  module Config = struct
    type t

    external make :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit ->
      t = "" [@@bs.obj]
  end


  external createConnection : Config.t -> t = "" [@@bs.module "mysql2"]
  external close : t -> unit = "end" [@@bs.send]

  external execute : t -> 'a Js.t -> callback -> unit = "execute"
  [@@bs.send]

  let parse_response = Result.parse

  let make ?host ?port ?user ?password ?database _ =
    Config.make ?host ?port ?user ?password ?database () |> createConnection

  let execute conn sql (params:params) callback =
    let options = Options.from_params sql params
    in
    execute conn options callback

  module Promise = struct
    let close conn x = Js.Promise.(
      resolve(x)
      |> then_ (fun x -> let _ = close conn in x)
    )
  end
end


let connect _ = Connection.make
  ~host:"127.0.0.1"
  ~port:3306
  ~user:"root"
  ()
