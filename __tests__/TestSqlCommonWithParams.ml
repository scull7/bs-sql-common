open Jest

module Sql = SqlCommon.Make_sql(MySql2)

external jsonIntMatrix : int array array -> Js.Json.t = "%identity"

type result = {
  result: int;
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
