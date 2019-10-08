external sqlformat :
 string
  -> 'a Js.Array.t
  -> string
 = "format" [@@bs.module "sqlstring"]

type 'a iteration = {
  rows: 'a array;
  count: int;
  last_insert_id: int;
}

let iteration rows count last_insert_id = { rows; count; last_insert_id; }

let db_call ~execute ~sql ?params ~fail ~ok _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Mutation ((count:int), (id:int)) -> ok count id
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

let rec run ~batch_size ~iterator ~fail ~ok iteration =
  let next = run ~batch_size ~iterator ~fail ~ok in
  let { rows; count; last_insert_id; } = iteration in
  match rows with
  | [||] -> ok count last_insert_id
  | r -> iterator ~batch_size ~rows:r ~fail ~ok:next ()

let insert execute ?batch_size ~table ~columns ~rows user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fail = (fun err -> rollback ~execute
    ~fail:(fun err -> user_cb (`Error err))
    ~ok:(fun _ _ -> user_cb (`Error err))
    ()
  )
  in
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
