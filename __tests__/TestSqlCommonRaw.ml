open Jest

type simple = {
  id: int;
  code: string;
}

module Sql = SqlCommon.Make_sql(MySql2)

let () =
describe "Raw SQL Query Test" (fun () ->
  let conn = TestUtil.connect () in
  let _ = afterAll (fun _ -> Sql.close conn) in

  testAsync "Expect a test database to be listed" (fun finish ->
    Sql.query conn ~sql:"SHOW DATABASES" (fun res ->
      match res with
      | `Error e -> raise e
      | `Select (rows, _) ->
        Belt_Array.map rows (Json.Decode.dict Json.Decode.string)
        |> Js.Array.map (fun x -> Js.Dict.unsafeGet x "Database")
        |> Expect.expect
        |> Expect.toContain @@ "test"
        |> finish
    )
  )
);

describe "Raw SQL Query Test Sequence" (fun () ->
  let conn = TestUtil.connect () in
  let table_sql = {|
    CREATE TABLE IF NOT EXISTS test.simple (
      `id` bigint(20) NOT NULL AUTO_INCREMENT
    , `code` varchar(32) NOT NULL
    , PRIMARY KEY(`id`)
    )
  |}
  in
  let drop next =
    let _ = Sql.mutate conn ~sql:"DROP TABLE IF EXISTS test.simple" (fun resp ->
      match resp with
      | `Error e -> let _ = Js.log2 "DROP FAILED: " e in raise e
      | `Mutation _ -> next ()
    ) in ()
  in
  let create next =
    let _ = Sql.mutate conn ~sql:table_sql (fun resp ->
      match resp with
      | `Error e -> let _ = Js.log2 "CREATE FAILED: " e in raise e
      | `Mutation _ -> next ()
    ) in ()
  in
  let _ = beforeAllAsync (fun finish ->
    drop (fun _ -> create finish))
  in

  testAsync "Expect a mutation result for an INSERT query" (fun finish ->
    Sql.mutate conn ~sql:"INSERT INTO test.simple (code) VALUES ('foo')" (fun resp ->
      match resp with
      | `Error e -> let _ = Js.log e in finish (fail "see log")
      | `Mutation (count, id) ->
        let affected_rows = count == 1 in
        let insert_id = id > 0 in
        Expect.expect [|affected_rows; insert_id|]
        |> Expect.toBeSupersetOf [|true; true|]
        |> finish
    )
  );

  testAsync "Expect an error result for an SELECT query called via mutate" (fun finish ->
    Sql.mutate conn ~sql:"SELECT * FROM test.simple" (fun resp ->
      match resp with
      | `Error e ->
        match e with
        | SqlCommon.InvalidResponse s -> Expect.expect s |> Expect.toContainString "ERR_UNEXPECTED_SELECT" |> finish
        | _ -> fail "Unexpected failure mode" |> finish
      | _ ->
        fail "This should have returned an InvalidResponse exception" |> finish
    )
  );

  testAsync "Expect a mutation result for an INSERT query" (fun finish ->
    Sql.mutate conn ~sql:"INSERT INTO test.simple (code) VALUES ('bar'), ('baz')" (fun resp ->
      match resp with
      | `Error e -> let _ = Js.log e in finish (fail "see log")
      | `Mutation (count, id) ->
        let affected_rows = count == 2 in
        let insert_id = id > 0 in
        Expect.expect [|affected_rows; insert_id|]
        |> Expect.toBeSupersetOf [|true; true|]
        |> finish
    )
  );

  testAsync "Expect a SELECT NULL to return an empty array" (fun finish ->
    let decoder = Json.Decode.dict (Json.Decode.nullable Json.Decode.string) in
    Sql.query conn ~sql:"SELECT NULL FROM test.simple WHERE false" (fun res ->
      match res with
      | `Error e -> let _ = Js.log e in finish (fail "see log")
      | `Select (rows, _) ->
        Belt_Array.map rows decoder
        |> Expect.expect
        |> Expect.toHaveLength 0
        |> finish
      )
  );

  testAsync "Expect an error result for an INSERT called via query" (fun finish ->
    Sql.query conn ~sql:"INSERT INTO test.simple (code) VALUES ('failure')" (fun res ->
      match res with
      | `Error e ->
        match e with
        | SqlCommon.InvalidResponse s -> Expect.expect s |> Expect.toContainString "ERR_UNEXPECTED_MUTATION" |> finish
        | _ -> fail "Unexpected failure mode" |> finish
      | _ ->
        fail "This should have returned an InvalidResponse exception" |> finish
    )
  );

  testAsync "Expect a SELECT with one parameter to respond with one column" (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    let pick = function
      | [| {id; code } |] -> [| (id == 1); (code == "foo") |]
      | [||] -> failwith "empty"
      | _ -> failwith "unknown"
    in
    let params = Some(`Positional (Json.Encode.array Json.Encode.int [|1|])) in
    Sql.query conn ~sql:"SELECT * FROM test.simple WHERE test.simple.id = ?" ?params (fun res ->
      match res with
      | `Error e -> let _ = Js.log e in finish (fail "see log")
      | `Select (rows, _) ->
        Belt_Array.map rows decoder
        |> pick
        |> Expect.expect
        |> Expect.toBeSupersetOf [|true; true|]
        |> finish
    )
  );

  testAsync "Expect a SELECT * to respond with 4 rows" (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    Sql.query conn ~sql:"SELECT * FROM test.simple" (fun res ->
      match res with
      | `Error e -> let _ = Js.log e in finish (fail "see log")
      | `Select (rows, _) ->
        Belt_Array.map rows decoder
        |> Expect.expect
        |> Expect.toHaveLength 4
        |> finish
    )
  );
);
