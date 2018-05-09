external sqlformat : string -> Js.Json.t -> string = "format"
[@@bs.module "sqlstring"]

external array_to_params : 'a array -> [`Positional of Js.Json.t] = "%identity"
external params_to_array : [`Positional of Js.Json.t] -> 'a array = "%identity"

type iteration = {
  params: [`Positional of Js.Json.t];
  data: Js.Json.t array;
  meta: MySql2.meta_record array;
}

let iteration ?prev params data meta  =
  match prev with
  | None -> { params; data; meta; }
  | Some(p) ->
    let data = Belt_Array.concat p.data data in
    let meta = Belt_Array.concat p.meta meta in
    { params; data; meta; }

    let db_call ~execute ~sql ?params ~fail ~ok _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Select ((data:Js.Json.t array), (meta:MySql2.meta)) -> ok data meta
  )
  in ()

(* Takes the params from positional to 'a for sqlformat *)
let unwrap params =
  match params with
  | `Positional p -> p

let query_batch ~execute ~sql ~params ~fail ~ok _ =
  let sql_with_params = sqlformat sql (unwrap params) in
  let _ = Js.log("in query_batch", sql_with_params) in
  db_call ~execute ~sql:sql_with_params ~fail ~ok ()

let iterate ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
  let params_array = params_to_array (params) in
  let len = Belt_Array.length params_array in
  let batch = array_to_params (Belt_Array.slice params_array ~offset:0 ~len:batch_size) in
  let _ = Js.log("batch in iterate", batch) in
  let rest = array_to_params (Belt_Array.slice params_array ~offset:batch_size ~len:len) in
  let execute = (fun () -> query_batch_partial
    ~params:batch
    ~fail
    ~ok: (fun data meta -> ok (iteration ~prev rest data meta ))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let rec run ~batch_size ~iterator ~fail ~ok iteration =
  let run_without_iteration = run ~batch_size ~iterator ~fail ~ok in
  let { params; data; meta } = iteration in
  match Belt_Array.length (params_to_array params) with
  | 0 -> ok data meta
  | _ -> iterator ~batch_size ~params ~fail ~ok:run_without_iteration ~prev:iteration ()

let query execute ?batch_size ~sql ~params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun e -> user_cb (`Error e)) in
  let complete = (fun data meta ->
    user_cb(`Select(data, meta))
  ) in
  let query_batch_partial = query_batch ~execute ~sql in
  let iterator = iterate ~query_batch_partial in
  run
    ~batch_size
    ~iterator
    ~fail
    ~ok:complete
    (iteration params [||] [||])
