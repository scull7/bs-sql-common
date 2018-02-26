open Jest

type result = {
  result: int;
}

let get_result { result } = result

let expect value decoder finish =
  TestUtil.expect_select finish (fun next { rows; _ } ->
    Belt_Array.map rows (fun x -> x |> decoder |> get_result)
    |> Expect.expect
    |> Expect.toBeSupersetOf [|value|]
    |> next
  )

let () =

describe "Test parameter interpolation" (fun () ->
  let conn = TestUtil.connect () in
  let decoder json = Json.Decode.({ result = json |> field "result" int; }) in

  describe "Standard (positional) parameters" (fun () ->
    testAsync "Expect parameters to be substituted properly" (fun finish ->
      SqlCommon.with_params
        conn
        "SELECT 1 + ? + ? AS result"
        [|5;6|]
        (expect 12 decoder finish)
    )
  );

  describe "Named parameters" (fun () ->
    testAsync "Expect parameters to be substituted properly" (fun finish ->
      SqlCommon.with_named_params
        conn
        "SELECT :x + :y AS result"
        [%bs.obj { x = 1; y = 2 }]
        (expect 3 decoder finish)
    )
  );
);
