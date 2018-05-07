external sqlformat : string -> 'a Js.Array.t -> string = "format"
[@@bs.module "sqlstring"]

type 'a iteration = {
  rows: 'a array;
  count: int;
  last_insert_id: int;
}

let iteration rows count last_insert_id = { rows; count; last_insert_id; }

let db_call ~execute ~sql ?params ~fail ~ok_db _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Mutation ((count:int), (id:int)) -> ok_db count id
  )
  in ()

let rollback ~execute ~fail ~ok_db _ = db_call ~execute ~sql:"ROLLBACK" ~fail ~ok_db ()

let commit ~execute ~fail ~ok_db _ =
  let rollback = (fun err -> rollback ~execute
    ~fail:(fun err -> fail err)
    ~ok_db:(fun _ _ -> fail err)
    ()
  )
  in
  db_call ~execute ~sql:"COMMIT" ~fail:rollback ~ok_db ()

let insert_batch ~execute ~table ~columns ~rows ~fail ~ok_db _ =
  let params = [|columns; rows|] in
  (*
    Have to use this because MySQL2 doesn't properly
    handle the table name escaping
   *)
  let sql = sqlformat {j|INSERT INTO $table (??) VALUES ?|j} params in
  db_call ~execute ~sql ~fail ~ok_db ()

let iterate ~insert_batch ~batch_size ~rows ~fail ~ok_iteration _ =
  let len = Belt_Array.length rows in
  let batch = Belt_Array.slice rows ~offset:0 ~len:batch_size in
  let rest = Belt_Array.slice rows ~offset:batch_size ~len:len in
  let execute = (fun () -> insert_batch
    ~rows:batch
    ~fail
    ~ok_db: (fun count id -> ok_iteration (iteration rest count id))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in ()

let rec run ~batch_size ~iterator ~fail ~ok_db iteration =
  let next = run ~batch_size ~iterator ~fail ~ok_db in
  let { rows; count; last_insert_id; } = iteration in
  match rows with
  | [||] -> ok_db count last_insert_id
  | r -> iterator ~batch_size ~rows:r ~fail ~ok_iteration:next ()

let insert execute ?batch_size ~table ~columns ~rows user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun e -> user_cb (`Error e)) in
  let complete = (fun count id ->
    let ok_db = (fun _ _ -> user_cb (`Mutation (count, id)))
    in
    commit ~execute ~fail ~ok_db ()
  )
  in
  let insert_batch = insert_batch ~execute ~table ~columns in
  let iterator = iterate ~insert_batch in
  let ok_db = (fun _ _ ->
    run
      ~batch_size
      ~iterator
      ~fail
      ~ok_db:complete
      (iteration rows 0 0)
  )
  in
  db_call ~execute ~sql:"START TRANSACTION" ~fail ~ok_db ()
