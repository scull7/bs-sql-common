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

let expect name value decoder next res =
  match res with
  | Belt.Result.Error e -> e |. Js.String.make |. fail |. next
  | Belt.Result.Ok select ->
    select
    |. Sql.Response.Select.mapDecoder (fun x -> x |. decoder |. get_result)
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
      let next = expect name 12 decoder finish in
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
      let next = expect name 3 decoder finish in
      let json = Json.Encode.(object_ [
        ("x", int 1);
        ("y", int 2);
      ])
      in
      let params = Some(Sql.Params.positional json)
      in
      Sql.query ~db ~sql:"SELECT :x + :y AS result" ?params next
    )
  );

  testAsync "Expect a SELECT with two parameters to fail if not batched"
  (fun finish ->
    let params =
      [| [| 1; 2; |] |]
      |> Json.Encode.array (Json.Encode.array Json.Encode.int)
      |. Sql.Params.positional
      |. Some
    in
    let sql = "SELECT * FROM test.simple WHERE test.simple.id IN (?)"
    in
    Sql.query ~db ~sql ?params (fun res ->
      match res with
      | Belt.Result.Ok _ ->
          fail "A select with an IN should have been rejected." |. finish
      | Belt.Result.Error e ->
        match e with
        | SqlCommon.Exn.InvalidQuery _ -> pass |. finish
        | e -> e |. Js.String.make |. fail |. finish
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
    let params = `Positional(jsonIntMatrix [| [| 1; 2; |] |])
    in
    let batch_size = 10
    in
    Sql.Batch.query ~db ~batch_size ~sql ~params (fun res ->
    match res with
    | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
    | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.mapDecoder decoder
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
    let params = `Positional(jsonIntMatrix [| [| 1; 2; 3; |] |])
    in
    let batch_size = 2
    in
    Sql.Batch.query ~db ~batch_size ~sql ~params (fun res ->
    match res with
    | Belt.Result.Error e -> e |. Js.String.make |. fail |. finish
    | Belt.Result.Ok select ->
        select
        |. Sql.Response.Select.mapDecoder decoder
        |. Expect.expect
        |> Expect.toHaveLength 3
        |. finish
    )
  );

  (* I am unsure if this should match on an error code (not implemented), simply 'ERR_INVALID_QUERY', or a detailed error message *)
  testAsync "Expect a SELECT with two positional parameters for two variable substitutions to succeed if batched"
  (fun finish ->
    let sql = {|
      SELECT *
      FROM test.simple
      WHERE test.simple.id IN (?)
      AND test.simple.number IN (?)
    |}
    in
    let params = `Positional(
      jsonIntMatrix [| [| 1; 2; |]; [| 111; 222;|]; |]
    )
    in
    let batch_size = 10 in
    Sql.Batch.query ~db ~batch_size ~sql ~params (fun res ->
    match res with
    | Belt.Result.Ok _ ->
      fail "A select with two parameters should have been rejected." |. finish
    | Belt.Result.Error e ->
      match e with
      | SqlCommon.Exn.InvalidQuery _ -> pass |. finish
      | e -> e |. Js.String.make |. fail |. finish
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
      | SqlCommon.Exn.InvalidQuery _ -> pass |. finish
      | e -> e |. Js.String.make |. fail |. finish
    )
  );
);
