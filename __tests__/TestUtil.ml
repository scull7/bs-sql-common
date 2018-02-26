(*
  This needs to be imported from bs-mysql2, need to add bs-mysql2 as a
  dev dependency.
*)
module Connection = struct
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

  type t

  external createConnection : Config.t -> t = "" [@@bs.module "mysql2"]
  external close : t -> unit = "end" [@@bs.send]

  let make ?host ?port ?user ?password ?database _ =
    Config.make ?host ?port ?user ?password ?database () |> createConnection

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

let assert_mutation next handler resp =
  match resp with
  | SqlCommon.Response.Error e -> raise e
  | SqlCommon.Response.Select _ -> failwith "unexpected_select"
  | SqlCommon.Response.Mutation m -> handler next m

let expect_mutation next handler resp =
  match resp with
  | SqlCommon.Response.Error _ -> Jest.fail "unexpected_exception" |> next
  | SqlCommon.Response.Select _ -> Jest.fail "unexpected_select" |> next
  | SqlCommon.Response.Mutation m -> handler next m

let expect_select next handler resp =
  match resp with
  | SqlCommon.Response.Error _ -> Jest.fail "unexpected_exception" |> next
  | SqlCommon.Response.Mutation _ -> Jest.fail "unexpected_mutation" |> next
  | SqlCommon.Response.Select s -> handler next s
