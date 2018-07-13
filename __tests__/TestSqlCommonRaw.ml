open Jest

type simple = {
  id: int;
  code: string;
}

module Sql = TestUtil.Sql

let () =
describe "Raw SQL Query Test" (fun () ->
  let db = TestUtil.connect () in
  let _ = afterAll (fun _ -> Sql.Connection.close db) in

  testAsync "Expect a test database to be listed" (fun finish ->
    Sql.query ~db ~sql:"SHOW DATABASES" (fun res ->
      match res with
      | Belt.Result.Error e -> raise e
      | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.mapDecoder (Json.Decode.dict Json.Decode.string)
        |. Belt.Array.map (fun x -> Js.Dict.unsafeGet x "Database")
        |. Expect.expect
        |> Expect.toContain @@ "test"
        |. finish
    )
  )
);

describe "Raw SQL Query Test Sequence" (fun () ->
  let db = TestUtil.connect () in
  let table_sql = {|
    CREATE TABLE IF NOT EXISTS test.sql_common_raw (
      `id` bigint(20) NOT NULL AUTO_INCREMENT
    , `code` varchar(32) NOT NULL
    , PRIMARY KEY(`id`)
    )
  |}
  in
  let drop next =
    let _ = Sql.mutate ~db ~sql:"DROP TABLE IF EXISTS test.sql_common_raw" (fun resp ->
      match resp with
      | Belt.Result.Error e -> let _ = Js.log2 "DROP FAILED: " e in raise e
      | Belt.Result.Ok _ -> next ()
    ) in ()
  in
  let create next =
    let _ = Sql.mutate ~db ~sql:table_sql (fun resp ->
      match resp with
      | Belt.Result.Error e -> let _ = Js.log2 "CREATE FAILED: " e in raise e
      | Belt.Result.Ok _ -> next ()
    ) in ()
  in
  let _ = beforeAllAsync (fun finish ->
    drop (fun _ -> create finish))
  in

  testAsync "Expect a mutation result for an INSERT query" (fun finish ->
    Sql.mutate ~db ~sql:"INSERT INTO test.sql_common_raw (code) VALUES ('foo')" (fun resp ->
      match resp with
      | Belt.Result.Error e -> let _ = Js.log e in finish (fail "see log")
      | Belt.Result.Ok mutation ->
        mutation
        |. Sql.Response.Mutation.affectedRows
        |. Expect.expect
        |> Expect.toBe 1
        |. finish
    )
  );

  testAsync "Expect an error result for an SELECT query called via mutate" (fun finish ->
    Sql.mutate ~db ~sql:"SELECT * FROM test.sql_common_raw" (fun resp ->
      match resp with
      | Belt.Result.Ok _ ->
        fail "This should have returned an InvalidResponse exception" |> finish
      | Belt.Result.Error e ->
        match e with
        | SqlCommon.Exn.Invalid.Response.ExpectedMutation _ -> pass |. finish
        | e -> e |. Js.String.make |. fail |. finish
    )
  );

  testAsync "Expect a mutation result for an INSERT query" (fun finish ->
    Sql.mutate ~db ~sql:"INSERT INTO test.sql_common_raw (code) VALUES ('bar'), ('baz')"
    (fun resp ->
      match resp with
      | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
      | Belt.Result.Ok mutation ->
        mutation
        |. Sql.Response.Mutation.affectedRows
        |. Expect.expect
        |> Expect.toBe 2
        |. finish
    )
  );

  testAsync "Expect a SELECT NULL to return an empty array" (fun finish ->
    let decoder = Json.Decode.dict (Json.Decode.nullable Json.Decode.string) in
    Sql.query ~db ~sql:"SELECT NULL FROM test.sql_common_raw WHERE false" (fun res ->
      match res with
      | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
      | Belt.Result.Ok select ->
          Sql.Response.Select.mapDecoder select decoder
          |> Expect.expect
          |> Expect.toHaveLength 0
          |> finish
      )
  );

  testAsync "Expect an error result for an INSERT called via query" (fun finish ->
    Sql.query ~db ~sql:"INSERT INTO test.sql_common_raw (code) VALUES ('failure')" (fun res ->
      match res with
      | Belt.Result.Ok _ ->
        fail "This should have returned an InvalidResponse exception" |> finish
      | Belt.Result.Error e ->
        match e with
        | SqlCommon.Exn.Invalid.Response.ExpectedSelect _ -> pass |. finish
        | e -> e |. Js.String.make |. fail |. finish
    )
  );

  testAsync "Expect a SELECT with one parameter to respond with one column"
  (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    let pick = function
      | [| {id; code } |] -> [| (id == 1); (code == "foo") |]
      | [||] -> failwith "empty"
      | _ -> failwith "unknown"
    in
    let sql = "SELECT * FROM test.sql_common_raw WHERE test.sql_common_raw.id = ?"
    in
    let params =
      Json.Encode.array Json.Encode.int [| 1 |]
      |. Sql.Params.positional
      |. Some
    in
    Sql.query ~db ~sql ?params
    (fun res ->
      match res with
      | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
      | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.mapDecoder decoder
        |. pick
        |. Expect.expect
        |> Expect.toBeSupersetOf [|true; true|]
        |. finish
    )
  );

  testAsync "Expect a SELECT * to respond with 4 rows" (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    Sql.query ~db ~sql:"SELECT * FROM test.sql_common_raw" (fun res ->
      match res with
      | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
      | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.mapDecoder decoder
        |. Expect.expect
        |> Expect.toHaveLength 4
        |> finish
    )
  );
);
