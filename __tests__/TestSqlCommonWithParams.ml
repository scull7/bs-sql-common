open Jest

module Sql = SqlCommon.Make_sql(MySql2)

external jsonIntMatrix : int array array -> Js.Json.t = "%identity"

type result = {
  result: int;
}

type simple = {
  id: int;
  code: string;
}

let get_result { result } = result

let expect name value decoder next res =
  match res with
  | `Error e -> let _ = Js.log2 name e in next (fail {j|ERROR: $name|j})
  | `Select (rows, _) ->
    Belt_Array.map rows (fun x -> x |> decoder |> get_result)
    |> Expect.expect
    |> Expect.toBeSupersetOf [|value|]
    |> next

let () =

describe "Test parameter interpolation" (fun () ->
  let conn = TestUtil.connect () in
  let _ = afterAll (fun () -> Sql.close conn) in
  let decoder json = Json.Decode.({ result = json |> field "result" int; }) in
  let table_sql = {|
    CREATE TABLE IF NOT EXISTS test.simple (
      `id` bigint(20) NOT NULL AUTO_INCREMENT
    , `code` varchar(32) NOT NULL
    , PRIMARY KEY(`id`)
    )
  |}
  in
  let rows_sql = {| INSERT INTO test.simple (code) values ("foo"), ("bar"), ("baz") |}
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
  let insert next =
    let _ = Sql.mutate conn ~sql:rows_sql (fun resp ->
      match resp with
      | `Error e -> let _ = Js.log2 "INSERT FAILED: " e in raise e
      | `Mutation _ -> next ()
    ) in ()
  in
  let _ = beforeAllAsync (fun finish ->
    drop (fun _ -> create (fun _ -> insert finish)))
  in

  describe "Standard (positional) parameters" (fun () ->
    let name = "Expect parameters to be substituted properly" in
    testAsync name (fun finish ->
      let next = expect name 12 decoder finish in
      let params = Some(`Positional (Json.Encode.array Json.Encode.int [|5;6|]))
      in
      Sql.query conn ~sql:"SELECT 1 + ? + ? AS result" ?params next
    )
  );

  describe "Named parameters" (fun () ->
    let name = "Expect parameters to be substituted properly" in
    testAsync name (fun finish ->
      let next = expect name 3 decoder finish in
      let json = Json.Encode.(object_ [
        ("x", int 1);
        ("y", int 2);
      ]) in
      let params = Some(`Named json)
      in
      Sql.query conn ~sql:"SELECT :x + :y AS result" ?params next
    )
  );

  testAsync "Expect a SELECT with two parameters to fail if not batched" (fun finish ->
    let params = Some(`Positional ( jsonIntMatrix [|[|1;2|]|])) in
    Sql.query conn ~sql:"SELECT * FROM test.simple WHERE test.simple.id IN (?)" ?params (fun res ->
    match res with
    | `Select (_, _) ->
      fail "A select with an IN should have been rejected."
      |> finish
    | `Error e ->
      match e with
      | SqlCommon.InvalidQuery s -> Expect.expect s |> Expect.toContainString "ERR_INVALID_QUERY" |> finish
      | _ -> fail "Unexpected failure mode" |> finish
    )
  );

  (* Cover the case with batch_size > length of substitution array *)
  testAsync "Expect a SELECT with two positional parameters to succeed if batched (A)" (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    let params = `Positional (jsonIntMatrix [|[|1;2|]|]) in
    let batch_size = 10 in
    Sql.query_batch conn ~batch_size ~sql:"SELECT * FROM test.simple WHERE test.simple.id IN (?)" ~params (fun res ->
    match res with
    | `Error e -> let _ = Js.log e in finish (fail "see log")
    | `Select (rows, _) ->
      Belt_Array.map rows decoder
      |> Expect.expect
      |> Expect.toHaveLength 2
      |> finish
    )
  );

  (* Cover the case with batch_size < length of substitution array *)
  testAsync "Expect a SELECT with two positional parameters to succeed if batched (B)" (fun finish ->
  let decoder json = Json.Decode.({
    id = json |> field "id" int;
    code = json |> field "code" string;
  }) in
  let params = `Positional (jsonIntMatrix [|[|1;2;3|]|]) in
  let batch_size = 2 in
  Sql.query_batch conn ~batch_size ~sql:"SELECT * FROM test.simple WHERE test.simple.id IN (?)" ~params (fun res ->
  match res with
  | `Error e -> let _ = Js.log e in finish (fail "see log")
  | `Select (rows, _) ->
    Belt_Array.map rows decoder
    |> Expect.expect
    |> Expect.toHaveLength 3
    |> finish
  )
  );

  (* I am unsure if this should match on an error code (not implemented), simply 'ERR_INVALID_QUERY', or a detailed error message *)
  testAsync "Expect a SELECT with two positional parameters for two variable substitutions to succeed if batched" (fun finish ->
    let params = `Positional (jsonIntMatrix [|[|1;2|]; [|111; 222|]|]) in
    let batch_size = 10 in
    Sql.query_batch conn ~batch_size ~sql:"SELECT * FROM test.simple WHERE test.simple.id IN (?) AND test.simple.number IN (?)" ~params (fun res ->
    match res with
    | `Select (_, _) ->
      fail "A select with two parameters should have been rejected."
      |> finish
    | `Error e ->
      match e with
      | SqlCommon.InvalidQuery s -> Expect.expect s |> Expect.toContainString "Do not use query_batch for queries with multiple parameters" |> finish
      | _ -> fail "Unexpected failure mode" |> finish
    )
  );

  (* What about batched queries with named parameters? *)

  testAsync "Expect a UPDATE with two parameters to fail if not batched" (fun finish ->
    let params = Some(`Positional ( jsonIntMatrix [|[|2;3|]|])) in
    Sql.mutate conn ~sql:"UPDATE test.simple set code = 'aaaa' WHERE id IN (2,3)" ?params (fun res ->
    match res with
    | `Mutation (_, _) ->
      fail "A mutation with an IN should have been rejected."
      |> finish
    | `Error e ->
      match e with
      | SqlCommon.InvalidQuery s -> Expect.expect s |> Expect.toContainString "ERR_INVALID_QUERY" |> finish
      | _ -> fail "Unexpected failure mode" |> finish
    )
  );
);
