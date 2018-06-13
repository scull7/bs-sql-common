external sqlformat :
  string
  -> ([`Positional of Js.Json.t][@bs.unwrap])
  -> string
  = "format" [@@bs.module "sqlstring"]

external array_to_params : 'a array -> [`Positional of Js.Json.t] = "%identity"
external params_to_array : [`Positional of Js.Json.t] -> 'a array = "%identity"
external to_array : 'a -> 'b array array = "%identity"
external to_params : 'a -> [`Positional of Js.Json.t] = "%identity"

type iteration = {
  params: [`Positional of Js.Json.t];
  data: Js.Json.t array;
  meta: MySql2.metaRecord array;
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
  let sql_with_params = sqlformat sql params in
  db_call ~execute ~sql:sql_with_params ~fail ~ok ()

  let iterate ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
    let params_array = params_to_array (params) in
    let unsafe_inner_params = Belt_Array.get params_array 0 in
    let inner_params = match unsafe_inner_params with
    | Some arr -> arr
    | None -> [||]
    in
    let len = Belt_Array.length inner_params in
    let batch_as_array = Belt_Array.slice inner_params ~offset:0 ~len:batch_size in
    let batch = array_to_params [|batch_as_array|] in
    let rest_as_array = Belt_Array.slice inner_params ~offset:batch_size ~len: len in
    let rest = array_to_params [|rest_as_array|] in
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
  let params_array = params_to_array (params) in
  let elem = Belt_Array.get params_array 0 in
  let inner = match elem with
  | Some arr -> arr
  | None -> [||]
  in
  match Belt_Array.length inner with
  | 0 -> ok data meta
  | _ -> iterator ~batch_size ~params ~fail ~ok:run_without_iteration ~prev:iteration ()

let valid_query_params params =
  let array_params = to_array (unwrap params) in
  match (Belt_Array.length array_params) with
  | 1 -> true
  | _ -> false

let query execute ?batch_size ~sql ~params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  (* Unwrap the params, then convert them back to params *)
  let p = unwrap params in
  let params_again = to_params p in
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
    (iteration params_again [||] [||])
