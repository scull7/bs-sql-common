[@bs.module "sqlstring"]
external sqlformat : string => Js.Array.t('a) => string = "format";

type iteration('a) = {
  rows: array('a),
  count: int,
  last_insert_id: int,
};

let iteration = (rows, count, last_insert_id) => {
  rows,
  count,
  last_insert_id,
};

let db_call = (~execute, ~sql, ~params=?, ~fail, ~ok, _) => {
  execute(~sql, ~params?, res =>
    switch res {
    | `Error(e) => fail(e)
    | `Mutation(count: int, id: int) => ok(count, id)
    }
  );
  ();
};

let rollback = (~execute, ~fail, ~ok, _) =>
  db_call(~execute, ~sql="ROLLBACK", ~fail, ~ok, ());

let commit = (~execute, ~fail, ~ok, _) => {
  let rollback = err =>
    rollback(
      ~execute,
      ~fail = err => fail(err),
      ~ok = (_, _) => fail(err),
      ()
    );
  db_call(~execute, ~sql="COMMIT", ~fail=rollback, ~ok, ());
};

let insert_batch = (~execute, ~table, ~columns, ~rows, ~fail, ~ok, _) => {
  let params = [|columns, rows|];
  
  /* Have do because MySQL2 doesn't properly handle table name escaping */
  let sql = sqlformat({j|INSERT INTO $table (??) VALUES ?|j}, params);
  db_call(~execute, ~sql, ~fail, ~ok, ());
};

let iterate = (~insert_batch, ~batch_size, ~rows, ~fail, ~ok, _) => {
  let len = Belt_Array.length(rows);
  let batch = Belt_Array.slice(rows, ~offset=0, ~len=batch_size);
  let rest = Belt_Array.slice(rows, ~offset=batch_size, ~len);
  let execute = () =>
    insert_batch(
      ~rows = batch,
      ~fail,
      ~ok = (count, id) => ok(iteration(rest, count, id)),
      ()
    );
  
  /* Trampoline, in case the connection driver is synchronous */
  let _ = Js.Global.setTimeout(execute, 0);
  ();
};

let rec run = (~batch_size, ~iterator, ~fail, ~ok, iteration) => {
  let next = run(~batch_size, ~iterator, ~fail, ~ok);
  let { rows, count, last_insert_id } = iteration;
  switch rows {
  | [||] => ok(count, last_insert_id)
  | r => iterator(~batch_size, ~rows=r, ~fail, ~ok=next, ())
  };
};

let insert = (execute, ~batch_size=?, ~table, ~columns, ~rows, user_cb) => {
  let batch_size =
    switch batch_size {
    | None => 1000
    | Some(s) => s
    };
  
  let fail = e => user_cb(`Error(e));
  let complete = (count, id) => {
    let ok = (_, _) => user_cb(`Mutation((count, id)));
    commit(~execute, ~fail, ~ok, ());
  };

  let insert_batch = insert_batch(~execute, ~table, ~columns);
  let iterator = iterate(~insert_batch);
  let ok = (_, _) => run(
      ~batch_size,
      ~iterator,
      ~fail,
      ~ok = complete,
      iteration(rows, 0, 0)
    );
  
  db_call(~execute, ~sql="START TRANSACTION", ~fail, ~ok, ());
};
