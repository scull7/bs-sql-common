external sqlformatparams : string -> Js.Json.t array -> string = "format"
[@@bs.module "sqlstring"]

type 'a iteration = {
  params: 'a array;
  data: Js.Json.t array;
  meta: MySql2.meta_record array;
}

let iteration ?prev params data meta  =
  match prev with
  | None -> { params; data; meta; }
  | Some(`iteration p) ->
    let data = Array.append p.data data in
    let meta = Array.append p.meta meta in
    { params; data; meta; }

(* Lowest *)
let db_call ~execute ~sql ~params ~fail ~ok _ =
  let _ = execute ~sql ~params (fun res ->
    match res with
    | `Error e -> fail e
    | `Select ((data:Js.Json.t array), (meta:MySql2.meta)) -> ok data meta
  )
  in ()

(* Does substitution, calls db *)
let query_batch ~execute ~sql ~params ~fail ~ok _ =
  let sql_with_params = sqlformatparams sql params in
  db_call ~execute ~sql:sql_with_params ~fail ~ok ()

let iterate ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
  let len = Belt_Array.length params in
  let batch = Belt_Array.slice params ~offset:0 ~len:batch_size in
  let rest = Belt_Array.slice params ~offset:batch_size ~len:len in
  let execute = (fun () -> query_batch_partial
    ~params:batch
    ~fail
    ~ok: (fun data meta -> ok (iteration ~prev rest data meta ))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let rec run ~batch_size ~iterator ~fail ~ok ~iteration =
  let next = run ~batch_size ~iterator ~fail ~ok ~iteration in
  let { params; data; meta } = iteration in
  match params with
  | [||] -> ok data meta
  | p -> iterator ~batch_size ~params:p ~fail ~ok:next ~prev:iteration ()

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
  let iterator = iterate ~query_batch_partial in
  let iteration = iteration params [||] [||] in
  run
    ~batch_size
    ~iterator
    ~fail
    ~ok
    ~iteration
