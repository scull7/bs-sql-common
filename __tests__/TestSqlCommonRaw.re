open Jest;

module Sql = SqlCommon.Make_sql(MySql2);

type simple = {
  id: int,
  code: string,
};

describe("Raw SQL Query Test", () => {
  let conn = TestUtil.connect();
  afterAll(() => conn |> Sql.close);

  testAsync("Expect a test database to be listed", finish => {
    Sql.query(conn, ~sql="SHOW DATABASES", res =>
      switch res {
      | `Error(e) => raise(e)
      | `Select((rows, _)) =>
        Belt_Array.map(rows, Json.Decode.dict(Json.Decode.string))
        |> Js.Array.map(x => "Database" |> Js.Dict.unsafeGet(x))
        |> Expect.expect
        |> Expect.toContain @@ "test"
        |> finish
      }
    )
  });  
});

describe("Raw SQL Query Test Sequence", () => {
  let conn = TestUtil.connect();
  afterAll(() => conn |> Sql.close);
  let table_sql = {|
    CREATE TABLE IF NOT EXISTS test.simple (
      `id` bigint(20) NOT NULL AUTO_INCREMENT
    , `code` varchar(32) NOT NULL
    , PRIMARY KEY(`id`)
    )
  |};

  let drop = next =>
    Sql.mutate(conn, ~sql="DROP TABLE IF EXISTS test.simple", res =>
      switch res {
      | `Error(e) => {
        Js.log2("DROP FAILED: ", e);
        raise(e)
      }
      | `Mutation(_) => next()
      }
    );
  
  let create = next =>
    Sql.mutate(conn, ~sql=table_sql, res =>
      switch res {
      | `Error(e) => {
        Js.log2("CREATE FAILED: ", e);
        raise(e)
      }
      | `Mutation(_) => next()
      }
    );
  
  beforeAllAsync(finish =>
    drop(() => finish |> create)
  );

  testAsync("Expect a mutation result for an INSERT query", finish =>
    Sql.mutate(conn, ~sql="INSERT INTO test.simple (code) VALUES ('foo')", res =>
      switch res {
      | `Error(e) => {
          Js.log(e);
          fail("see log") |> finish
        }
      | `Mutation((count, id)) => {
          let affected_rows = (count == 1);
          let insert_id = (id > 0);
          Expect.expect([|affected_rows, insert_id|])
          |> Expect.toBeSupersetOf([|true, true|])
          |> finish
        }
      }
    )
  );

  testAsync("Expect a SELECT NULL to return an empty array", finish => {
    let decoder = Json.Decode.dict(Json.Decode.nullable(Json.Decode.string));
    Sql.query(conn, ~sql="SELECT NULL FROM test.simple WHERE false", res =>
      switch res {
      | `Error(e) => {
          Js.log(e);
          fail("see log") |> finish
        }
      | `Select ((rows, _)) =>
        Belt_Array.map(rows, decoder)
        |> Expect.expect
        |> Expect.toHaveLength(0)
        |> finish
      }
    )
  });

  testAsync("Expect a SELECT * to respond with all the columns", finish => {
    let decoder = json => Json.Decode.{
      id: json |> field("id", int),
      code: json |> field("code", string),
    };

    let pick =
      fun
      | [|{ id, code }|] => [| (id === 1), (code === "foo") |]
      | [||] => failwith("empty")
      | _ => failwith("unknown")
    ;

    Sql.query(conn, ~sql="SELECT * FROM test.simple", res =>
      switch res {
      | `Error(e) => {
          Js.log(e);
          fail("see log") |> finish
        }
      | `Select((rows, _)) =>
        Belt_Array.map(rows, decoder)
        |> pick
        |> Expect.expect
        |> Expect.toBeSupersetOf([|true, true|])
        |> finish
      }
    )
  });
});
