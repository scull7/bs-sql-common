open Jest

module Sql = TestUtil.Sql

let jsonIntMatrix x = Belt.Array.map x (Json.Encode.array Json.Encode.int)

type result = {
  result: int;
}

type simple = {
  id: int;
  code: string;
}

let get_result { result } = result

let expect value decoder next res =
  match res with
  | Belt.Result.Error e -> e |. Js.String.make |. fail |. next
  | Belt.Result.Ok select ->
    select
    |. Sql.Response.Select.flatMap (fun x -> x |. decoder |. get_result)
    |. Expect.expect
    |> Expect.toBeSupersetOf [|value|]
    |. next

let () =

describe "Test parameter interpolation" (fun () ->
  let db = TestUtil.connect ()
  in
  let _ = afterAll (fun () -> Sql.Connection.close db)
  in
  let _ = beforeAllAsync (fun next -> TestUtil.init_test_simple db next)
  in
  let decoder json = Json.Decode.({ result = json |> field "result" int; })
  in

  describe "Standard (positional) parameters" (fun () ->
    let name = "Expect parameters to be substituted properly" in
    testAsync name (fun finish ->
      let next = expect 12 decoder finish in
      let params =
        Json.Encode.array Json.Encode.int [| 5; 6; |]
        |. Sql.Params.positional
        |. Some
      in
      Sql.query ~db ~sql:"SELECT 1 + ? + ? AS result" ?params next
    )
  );

  describe "Named parameters" (fun () ->
    let name = "Expect parameters to be substituted properly" in
    testAsync name (fun finish ->
      let next = expect 3 decoder finish in
      let json = Json.Encode.(object_ [
        ("x", int 1);
        ("y", int 2);
      ])
      in
      let params = Some(Sql.Params.named json)
      in
      Sql.query ~db ~sql:"SELECT :x + :y AS result" ?params next
    )
  );

  (* Cover the case with batch_size > length of substitution array *)
  testAsync "Expect a SELECT with two positional parameters to succeed if batched (A)"
  (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    })
    in
    let sql = "SELECT * FROM test.simple WHERE test.simple.id IN (?)"
    in
    let params = `Positional(Belt.Array.map [| 1; 2; |] Json.Encode.int)
    in
    let batch_size = 10
    in
    Sql.Batch.query ~db ~batch_size ~sql ~params (fun res ->
    match res with
    | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
    | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.flatMap decoder
        |. Expect.expect
        |> Expect.toHaveLength 2
        |. finish
    )
  );

  (* Cover the case with batch_size < length of substitution array *)
  testAsync "Expect a SELECT with two positional parameters to succeed if batched (B)"
  (fun finish ->
    let decoder json = Json.Decode.({
      id = json |> field "id" int;
      code = json |> field "code" string;
    })
    in
    let sql = "SELECT * FROM test.simple WHERE test.simple.id IN (?)"
    in
    let params = `Positional(Belt.Array.map [| 1; 2; 3; |] Json.Encode.int)
    in
    let batch_size = 2
    in
    Sql.Batch.query ~db ~batch_size ~sql ~params (fun res ->
    match res with
    | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
    | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.flatMap decoder
        |. Expect.expect
        |> Expect.toHaveLength 3
        |. finish
    )
  );

  (* What about batched queries with named parameters? *)

  testAsync "Expect a UPDATE with two parameters to fail if not batched"
  (fun finish ->
    let sql = "UPDATE test.simple set code = 'aaaa' WHERE id IN (2,3)"
    in
    let params =
      [| [| 2; 3; |] |]
      |> Json.Encode.array (Json.Encode.array Json.Encode.int)
      |. Sql.Params.positional
      |. Some
    in
    Sql.mutate ~db ~sql ?params (fun res ->
    match res with
    | Belt.Result.Ok _ -> 
      fail "A mutation with an IN should have been rejected." |. finish
    | Belt.Result.Error e ->
      match e with
      | SqlCommon.Exn.Invalid.Query.IllegalUseOfIn _ -> pass |. finish
      | e -> e |. Js.String.make |. fail |. finish
    )
  );

  testAsync "Expect a mutation result for an INSERT query" 
  (fun finish ->
    let sql = {|
    # the word in, in comments used to cause valid mutations to fail
    /* 
      multi-line comment 1, in
    */
    INSERT INTO test.sql_common_raw (code) VALUES ('bar'), ('baz') # single in-line comment, in
    /* multi-line comment 2, in */
    |}
    in
    Sql.mutate ~db ~sql:sql
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
);
