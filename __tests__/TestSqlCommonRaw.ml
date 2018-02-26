open Jest

type simple = {
  id: int;
  code: string;
}

let () =
describe "Raw SQL Query Test" (fun () ->
  let conn = TestUtil.connect () in
  let _ = afterAll (fun _ -> TestUtil.Connection.close conn) in

  testAsync "Expect a test database to be listed" (fun finish ->
    SqlCommon.raw conn "SHOW DATABASES" (fun results ->
      match results with
      | SqlCommon.Response.Error _ -> fail "unexpected_exception" |> finish
      | SqlCommon.Response.Mutation _ -> fail "unexpected_mutation" |> finish
      | SqlCommon.Response.Select s ->
        s.rows
        |> Js.Array.map (Json.Decode.dict Json.Decode.string)
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
    let _ = SqlCommon.raw conn "DROP TABLE IF EXISTS test.simple" (fun resp ->
      match resp with
      | SqlCommon.Response.Error e -> raise e
      | SqlCommon.Response.Select _ -> failwith "unexpected_select_result"
      | SqlCommon.Response.Mutation _ -> next ()
    ) in ()
  in
  let create next =
    let _ = SqlCommon.raw conn table_sql (fun resp ->
      match resp with
      | SqlCommon.Response.Error e -> raise e
      | SqlCommon.Response.Select _ -> failwith "unexpected_select_result"
      | SqlCommon.Response.Mutation _ -> next ()
    ) in ()
  in
  let _ = beforeAllAsync (fun finish -> drop (fun _ -> create finish)) in

  testAsync "Expect a mutation result for an INSERT query" (fun finish ->
    SqlCommon.raw conn "INSERT INTO test.simple (code) VALUES ('foo')" (fun resp ->
      match resp with
      | SqlCommon.Response.Error _ -> fail "unexpected_exception" |> finish
      | SqlCommon.Response.Select _ -> fail "unexpected_select" |> finish
      | SqlCommon.Response.Mutation m ->
        let affected_rows = m.affected_rows == 1 in
        let insert_id = Js.Option.isSome m.insert_id in
        Expect.expect [|affected_rows; insert_id|]
        |> Expect.toBeSupersetOf [|true; true|]
        |> finish
    )
  );

  testAsync "Expect a SELECT NULL to return an empty array" (fun finish ->
    let decoder = Json.Decode.dict (Json.Decode.nullable Json.Decode.string) in
    SqlCommon.raw
      conn
      "SELECT NULL FROM test.simple WHERE false"
      (TestUtil.expect_select finish (fun next { rows; _} ->
        Belt_Array.map rows decoder
        |> Expect.expect
        |> Expect.toHaveLength 0
        |> next
      ))
  );

  testAsync "Expect a SELECT * to respond with all the columns" (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    let pick = function
      | [| {id; code } |] -> [| (id == 1); (code == "foo") |]
      | [||] -> failwith "empty"
      | _ -> failwith "unknown"
    in
    SqlCommon.raw conn "SELECT * FROM test.simple" (
      TestUtil.expect_select finish (fun next { rows; _ } ->
        Belt_Array.map rows decoder
        |> pick
        |> Expect.expect
        |> Expect.toBeSupersetOf [|true; true|]
        |> next
      )
    )
  );
);
