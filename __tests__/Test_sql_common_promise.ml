open Jest

module Sql = TestUtil.Sql

let table = "test.sql_common_promise"

let table_sql = {j|
  CREATE TABLE IF NOT EXISTS $table (
    `id` bigint(20) NOT NULL AUTO_INCREMENT
  , `code` varchar(32) NOT NULL
  , `display` varchar(140) NOT NULL
  , PRIMARY KEY(id)
  )
|j}

let initialize db next =
  TestUtil.drop db "sql_common_promise" (fun _ ->
    TestUtil.mutate db table_sql next
  )

let columns = [| "code"; "desc"; |]

type row = {
  id: Sql.Id.t;
  code: string;
  display: string;
}

let decoder json = Json.Decode.{
  id = json |> field "id" Sql.Id.fromJson;
  code = json |> field "code" string;
  display = json |> field "display" string;
}

let () =

describe "SqlCommon :: Promise" (fun () ->
  let db = TestUtil.connect()
  in
  let _ = afterAll (fun () -> Sql.Connection.close db)
  in
  let _ = beforeAllAsync (fun next -> initialize db next)
  in
  describe "Select" (fun () ->
    testPromise "Should retrieve a row" (fun () ->
      let insert = {j| INSERT INTO $table (code, display) VALUES (?, ?)|j} in
      let params1 = Sql.Params.positional Json.Encode.(
        [| (string "gandalf"); (string "Gandalf the Grey"); |]
        |. jsonArray
      )
      in
      let select = {j| SELECT * FROM $table WHERE code = ? |j} in
      let params2 = Sql.Params.positional Json.Encode.(
        [| (string "gandalf") |] |. jsonArray
      )
      in
      Sql.Promise.mutate ~db ~params:params1 ~sql:insert
      |> Js.Promise.then_ (fun _ ->
          Sql.Promise.query ~db ~params:params2 ~sql:select
      )
      |> Js.Promise.then_ (fun select ->
        select
        |. Sql.Response.Select.flatMap decoder
        |. Belt.Array.map (fun x -> (x.code, x.display))
        |. Expect.expect
        |> Expect.toEqual [| ("gandalf", "Gandalf the Grey") |]
        |> Js.Promise.resolve
      )
    );

    testPromise "Should error when used for a mutation" (fun () ->
      let insert = {j| INSERT INTO $table (code, display) VALUES (?, ?)|j} in
      let params1 = Sql.Params.positional Json.Encode.(
        [| (string "bilbo"); (string "Bilbo Baggins"); |]
        |. jsonArray
      )
      in
      Sql.Promise.query ~db ~params:params1 ~sql:insert
        |> Js.Promise.then_ (fun _ ->
          "unexpected success" |. fail |. Js.Promise.resolve
        )
        |> Js.Promise.catch (fun e ->
          Js.String.make e
          |> Expect.expect
          |> Expect.toMatchRe [%re "/EXPECTED_SELECT/"]
          |> Js.Promise.resolve
        )
    );

    testPromise "Should error on invalid syntax" (fun () ->
      let select = {j| SELECT * FROM $table WHERE code = ? AND ? |j} in
      let params1 = Sql.Params.positional Json.Encode.(
        [| (string "gandalf") |] |. jsonArray
      )
      in
      Sql.Promise.query ~db ~params:params1 ~sql:select
        |> Js.Promise.then_ (fun _ ->
          "unexpected success" |. fail |. Js.Promise.resolve
        )
        |> Js.Promise.catch (fun e ->
          Js.String.make e
          |> Expect.expect
          |> Expect.toMatchRe [%re "/ER_PARSE_ERROR/"]
          |> Js.Promise.resolve
        )
    )
  );

  describe "Mutate" (fun () ->
    testPromise "Should error when used for a mutation" (fun () ->
      let select = {j| SELECT * FROM $table WHERE code = ? |j} in
      let params1 = Sql.Params.positional Json.Encode.(
        [| (string "gandalf") |] |. jsonArray
      )
      in
      Sql.Promise.mutate ~db ~params:params1 ~sql:select
        |> Js.Promise.then_ (fun _ ->
          "unexpected success" |. fail |. Js.Promise.resolve
        )
        |> Js.Promise.catch (fun e ->
          Js.String.make e
          |> Expect.expect
          |> Expect.toMatchRe [%re "/EXPECTED_MUTATION/"]
          |> Js.Promise.resolve
        )
    )
  )
)
