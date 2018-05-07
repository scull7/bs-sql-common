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

(* Lowest *)
let db_call ~execute ~sql ?params ~fail ~ok_db _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Select ((data:Js.Json.t array), (meta:MySql2.meta)) -> ok_db data meta
  )
  in ()

(* Takes the params from positional to 'a for sqlformat *)
let unwrap params =
  match params with
  | `Positional p -> p

(* Does substitution, calls db *)
let query_batch ~execute ~sql ~params ~fail ~ok_db _ =
  let sql_with_params = sqlformat sql (unwrap params) in
  db_call ~execute ~sql:sql_with_params ~fail ~ok_db ()

let iterate ~query_batch_partial ~batch_size ~(params:[`Positional of Js.Json.t]) ~fail ~ok_iteration ~prev _ =
  let params_array = params_to_array params in
  let len = Belt_Array.length params_array in
  let batch = array_to_params (Belt_Array.slice params_array ~offset:0 ~len:batch_size) in
  let rest = array_to_params (Belt_Array.slice params_array ~offset:batch_size ~len:len) in
  let execute = (fun () -> query_batch_partial
    ~params:batch
    ~fail
    ~ok_db: (fun data meta -> ok_iteration (iteration ~prev rest data meta ))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let rec run ~batch_size ~iterator ~fail ~ok_db ~iteration =
  let next = run ~batch_size ~iterator ~fail ~ok_db ~iteration in
  let { params; data; meta } = iteration in
  let _ = Js.log("data in run", data) in
  match Belt_Array.length (params_to_array params) with
  | 0 -> ok_db data meta
  | _ -> iterator ~batch_size ~params ~fail ~ok_iteration:next ~prev:iteration ()

(* let query execute ?batch_size ~sql ~params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun e -> user_cb (`Error e)) in
  let ok = (fun data meta -> user_cb (`Select (data, meta))) in
  let query_batch = query_batch ~execute ~sql ~params in
  query_batch ~fail ~ok () *)

(* let query execute ?batch_size ~sql ~params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun e -> user_cb (`Error e)) in
  let ok = (fun data meta -> user_cb (`Select (data, meta))) in
  let query_batch = query_batch ~execute ~sql ~params in
  query_batch ~fail ~ok () *)

let query execute ?batch_size ~sql ~params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let iteration = iteration params [||] [||] in
  let fail = (fun e -> user_cb (`Error e)) in
  let ok_db = (fun data meta ->
    let _ = Js.log("data", data) in
    let _ = Js.log("meta", meta) in
    user_cb (`Select (data, meta))
  ) in
  let complete = (fun data meta ->
    fun iteration -> user_cb(`Select(data, meta))
  ) in
  let query_batch_partial = query_batch ~execute ~sql in
  query_batch_partial ~params ~fail ~ok_db ()
  (* let iterator = iterate ~query_batch_partial ~prev:iteration in
  run
    ~batch_size
    ~iterator
    ~fail
    ~ok_db:complete
    ~iteration *)
