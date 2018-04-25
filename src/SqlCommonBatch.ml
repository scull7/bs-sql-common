
external sqlformat : string -> 'a Js.Array.t -> string = "format"
[@@bs.module "sqlstring"]

type 'a iteration = {
  rows: 'a array;
  count: int;
  last_insert_id: int;
}

type 'a query_iteration = {
  params: 'a array;
  data: Js.Json.t;
  meta: Js.Json.t;
}

let iteration rows count last_insert_id = { rows; count; last_insert_id; }

let query_iteration params data meta = { params; data; meta; }

let db_call ~execute ~sql ?params ~fail ~ok _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Mutation ((count:int), (id:int)) -> ok count id
  )
  in ()

let db_call_query ~execute ~sql ?params ~fail ~ok _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Select ((data:Js.Json.t), (meta:Js.Json.t)) -> ok data meta
  )
  in ()

let rollback ~execute ~fail ~ok _ = db_call ~execute ~sql:"ROLLBACK" ~fail ~ok ()

let commit ~execute ~fail ~ok _ =
  let rollback = (fun err -> rollback ~execute
    ~fail:(fun err -> fail err)
    ~ok:(fun _ _ -> fail err)
    ()
  )
  in
  db_call ~execute ~sql:"COMMIT" ~fail:rollback ~ok ()

let insert_batch ~execute ~table ~columns ~rows ~fail ~ok _ =
  let params = [|columns; rows|] in
  (*
    Have to use this because MySQL2 doesn't properly
    handle the table name escaping
   *)
  let sql = sqlformat {j|INSERT INTO $table (??) VALUES ?|j} params in
  db_call ~execute ~sql ~fail ~ok ()

let query_batch ~execute ~sql ~params ~fail ~ok _ =
  let sql_with_params = sqlformat sql params in
  db_call_query ~execute ~sql:sql_with_params ~fail ~ok ()

let iterate ~insert_batch ~batch_size ~rows ~fail ~ok _ =
  let len = Belt_Array.length rows in
  let batch = Belt_Array.slice rows ~offset:0 ~len:batch_size in
  let rest = Belt_Array.slice rows ~offset:batch_size ~len:len in
  let execute = (fun () -> insert_batch
    ~rows:batch
    ~fail
    ~ok: (fun count id -> ok (iteration rest count id))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let iterate_query ~query_batch ~batch_size ~params ~fail ~ok _ =
  let len = Belt_Array.length params in
  let batch = Belt_Array.slice params ~offset:0 ~len:batch_size in
  let rest = Belt_Array.slice params ~offset:batch_size ~len:len in
  let execute = (fun () -> query_batch
    ~params:batch
    ~fail
    ~ok: (fun data meta -> ok (query_iteration params data meta)) (* I think we merge the data here*)
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let rec run ~batch_size ~iterator ~fail ~ok iteration =
  let next = run ~batch_size ~iterator ~fail ~ok in
  let { rows; count; last_insert_id; } = iteration in
  match rows with
  | [||] -> ok count last_insert_id
  | r -> iterator ~batch_size ~rows:r ~fail ~ok:next ()

let rec run_query ~batch_size ~iterator ~fail ~ok query_iteration =
  let next = run_query ~batch_size ~iterator ~fail ~ok in
  let { params; data; meta } = query_iteration in
  match params with
  | [||] -> ok data meta
  | p -> iterator ~batch_size ~params:p ~fail ~ok:next ()

let insert execute ?batch_size ~table ~columns ~rows user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun e -> user_cb (`Error e)) in
  let complete = (fun count id ->
    let ok = (fun _ _ -> user_cb (`Mutation (count, id)))
    in
    commit ~execute ~fail ~ok ()
  )
  in
  let insert_batch = insert_batch ~execute ~table ~columns in
  let iterator = iterate ~insert_batch in
  let ok = (fun _ _ ->
    run
      ~batch_size
      ~iterator
      ~fail
      ~ok:complete
      (iteration rows 0 0)
  )
  in
  db_call ~execute ~sql:"START TRANSACTION" ~fail ~ok ()

let query execute ?batch_size ~sql params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun e -> user_cb (`Error e)) in
  let ok = (fun data meta -> user_cb (`Select (data, meta))) in
  let query_batch = query_batch ~execute ~sql params in
  let iterator_query = iterate_query ~query_batch in
  run_query
    ~batch_size
    ~iterator_query
    ~fail
    ~ok
    (iteration_query params (Js.Dict.empty ()) (Js.Dict.empty ()))
