module type Queryable = {
  type connection;
  type meta;
  type rows = array(Js.Json.t);

  type params =
    option([
    | `Named(Js.Json.t)
    | `Positional(Js.Json.t)
    ]);

  type callback =
    [ `Error(exn)
    | `Mutation(int, int)
    | `Select(rows, meta)
    ] => unit;

  let close: connection => unit;

  let connect: (
      ~host: string=?,
      ~port: int=?,
      ~user: string=?,
      ~password: string=?,
      ~database: string=?,
      unit) => connection;

  let execute: (connection, string, params, callback) => unit;
};

module type Make_store = {
  type connection;
  type error;
  type params =
    option([
    | `Named(Js.Json.t)
    | `Positional(array(Js.Json.t))
    ]);

  let close: connection => unit;

  let connect: (
      ~host:string=?,
      ~port:int=?,
      ~user:string=?,
      ~password:string=?,
      ~database:string=?,
      unit) => connection;

  let query: (
    connection,
    ~sql: string,
    ~params: params=?,
    [`Error(exn) | `Select(Js.Json.t, Js.Json.t)] => unit
  ) => unit;
  
  let mutate: (
    connection,
    ~sql: string,
    ~params: params=?,
    [`Error(exn) | `Mutation(int, int)] => unit
  ) => unit;
  
  let mutate_batch: (
    connection,
    ~batch_size: int=?,
    ~table: string,
    ~columns: Js.Json.t,
    ~rows: Js.Json.t,
    [> `Error(exn) | `Mutation(int, int)] => unit
  ) => unit;
};

module Make_sql = (Driver: Queryable) => {
  type sql = string;
  type params = Js.Json.t;
  type connection = Driver.connection;

  let close = Driver.close;
  let connect = Driver.connect;

  let invalid_response_mutation = Failure({|
    SqlCommonError - ERR_UNEXPECTED_MUTATION (99999)
    Invalid Response: Expected Select got Mutation
  |});

  let invalid_response_select = Failure({|
    SqlCommonError - ERR_UNEXPECTED_MUTATION (99999)
    Invalid Response: Expected Mutation got Select
  |});

  let query = (conn, ~sql, ~params=?, cb) =>
    Driver.execute(conn, sql, params, res =>
      switch (res) {
      | `Select(data, meta) => cb(`Select(data, meta))
      | `Mutation(_) => cb(`Error(invalid_response_mutation))
      | `Error(e) => cb(`Error(e))
      }
    );

  let mutate = (conn, ~sql, ~params=?, cb) =>
    Driver.execute(conn, sql, params, res =>
      switch (res) {
      | `Select(_) => cb(`Error(invalid_response_select))
      | `Mutation(changed, last_id) => cb(`Mutation(changed, last_id))
      | `Error(e) => cb(`Error(e))
      }
    );

  let mutate_batch = (conn, ~batch_size=?, ~table, ~columns, ~rows, cb) =>
    SqlCommonBatch.insert(
      mutate(conn),
      ~batch_size?,
      ~table,
      ~columns,
      ~rows,
      cb
    );

  module Promise: {
    let query: (
      connection,
      ~sql: string,
      ~params: [
      | `Named(Js.Json.t)
      | `Positional(Js.Json.t)
      ]=?,
      unit
    ) => Js.Promise.t((Driver.rows, Driver.meta));

    let mutate: (
      connection,
      ~sql: string,
      ~params: [
      | `Named(Js.Json.t)
      | `Positional(Js.Json.t)
      ]=?,
      unit
    ) => Js.Promise.t((int, int));

    let mutate_batch: (
      connection,
      ~batch_size: int=?,
      ~table: string,
      ~columns: array('a),
      ~rows: array('a)
    ) => Js.Promise.t((int, int));
  } = {
    let query = (conn, ~sql, ~params=?, _) =>
      Js.Promise.make(
        (~resolve, ~reject) =>
          query(
            conn,
            ~sql,
            ~params?,
            (res) =>
              switch res {
              | `Error(e) => [@bs] reject(e)
              | `Select(rows, meta) => [@bs] resolve((rows, meta))
              }
          )
      );
    let mutate = (conn, ~sql, ~params=?, _) =>
      Js.Promise.make(
        (~resolve, ~reject) =>
          mutate(
            conn,
            ~sql,
            ~params?,
            (res) =>
              switch res {
              | `Error(e) => [@bs] reject(e)
              | `Mutation(count, id) => [@bs] resolve((count, id))
              }
          )
      );
    let mutate_batch = (conn, ~batch_size=?, ~table, ~columns, ~rows) =>
      Js.Promise.make(
        (~resolve, ~reject) =>
          mutate_batch(
            conn,
            ~batch_size?,
            ~table,
            ~columns,
            ~rows,
            (res) =>
              switch res {
              | `Error(e) => [@bs] reject(e)
              | `Mutation(count, id) => [@bs] resolve((count, id))
              }
          )
      );
  };
};
