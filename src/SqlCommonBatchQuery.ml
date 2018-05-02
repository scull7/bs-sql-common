external sqlformatparams : string -> Js.Json.t array -> string = "format"
[@@bs.module "sqlstring"]

type 'a query_iteration = {
  params: 'a array;
  data: Js.Json.t array;
  meta: MySql2.meta_record array;
}

(* This could probably be combined with query_iteration using an optional argument *)
let query_iteration_original params =
  let data = [||] in
  let meta = [||] in
  { params; data; meta; }

let query_iteration params data meta prev =
  let data = Array.append prev.data data in
  let meta = Array.append prev.meta meta in
  { params; data; meta; }

(* That would probably look like this *)
(* let query_iteration params data meta prev =
  match prev with
  | None -> { params; data; meta; }
  | Some(`query_iteration p) ->
    let data = Array.append p.data data in
    let meta = Array.append p.meta meta in
    { params; data; meta; } *)

(* Lowest *)
let db_call_query ~execute ~sql ~params ~fail ~ok _ =
  let _ = execute ~sql ~params (fun res ->
    match res with
    | `Error e -> fail e
    | `Select ((data:Js.Json.t array), (meta:MySql2.meta)) -> ok data meta
  )
  in ()

(* Does substitution, calls db *)
let query_batch ~execute ~sql ~params ~fail ~ok _ =
  let sql_with_params = sqlformatparams sql params in
  db_call_query ~execute ~sql:sql_with_params ~fail ~ok ()

let iterate_query ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
  let len = Belt_Array.length params in
  let batch = Belt_Array.slice params ~offset:0 ~len:batch_size in
  let rest = Belt_Array.slice params ~offset:batch_size ~len:len in
  let execute = (fun () -> query_batch_partial
    ~params:batch
    ~fail
    ~ok: (fun data meta -> ok (query_iteration rest data meta prev))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let rec run_query ~batch_size ~iterator_query ~fail ~ok ~query_iteration =
  let next = run_query ~batch_size ~iterator_query ~fail ~ok ~query_iteration in
  let { params; data; meta } = query_iteration in
  match params with
  | [||] -> ok data meta
  | p -> iterator_query ~batch_size ~params:p ~fail ~ok:next ~prev:query_iteration ()

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
  let fail = (fun e -> user_cb (`Error e)) in
  let ok = (fun data meta -> user_cb (`Select (data, meta))) in
  let query_batch_partial = query_batch ~execute ~sql in
  let iterator_query = iterate_query ~query_batch_partial in
  let query_iteration = query_iteration_original params in
  run_query
    ~batch_size
    ~iterator_query
    ~fail
    ~ok
    ~query_iteration
