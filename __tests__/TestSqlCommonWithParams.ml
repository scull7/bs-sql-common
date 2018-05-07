open Jest

module Sql = SqlCommon.Make_sql(MySql2)

external jsonIntMatrix : int array array -> Js.Json.t = "%identity"

external jsonIntMatrixArr : int array array -> Js.Json.t = "%identity"

external jsonStringMatrix : string array array -> Js.Json.t = "%identity"

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

  testAsync "Expect a SELECT with two positional parameters to succeed if batched" (fun finish ->
    let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in
    let params = `Positional ( jsonIntMatrixArr [|[|1;2|]|]) in
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



  (* testAsync "Expect a batched INSERT with two positional parameters to succeed if batched" (fun finish ->
    (* let decoder json = Json.Decode.({
     id = json |> field "id" int;
     code = json |> field "code" string;
    }) in *)
    (* let params = Some(`Positional ( jsonStringMatrix [|[|"cats";"dogs"|]|])) in *)
    let batch_size = 10 in
    let columns = [|"code"|] in
    let rows = [|
      ("pangolin");
      ("2");
    |] in
    Sql.mutate_batch conn ~batch_size ~table:"simple" ~columns ~rows (fun res ->
    match res with
    | `Error e -> let _ = Js.log e in finish (fail "see log")
    | `Mutation (rows, b) ->
      let _ = Js.log(rows) in
      let _ = Js.log(b) in
      [|1;2|]
      |> Expect.expect
      |> Expect.toHaveLength 2
      |> finish
    )
  ); *)


);
