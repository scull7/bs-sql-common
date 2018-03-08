open Jest

module Sql = SqlCommon.Make_store(TestUtil.Connection)

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
      let params = Some(`Anonymous (Json.Encode.array Json.Encode.int [|5;6|]))
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
);
