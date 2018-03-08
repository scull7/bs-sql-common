open Jest

module Sql = SqlCommon.Make_store(TestUtil.Connection)

type result = {
  search: string;
}

let get_search { search } = search

let decoder json = Json.Decode.({ search = json |> field "search" string; })

let () =

describe "Test Promise based API" (fun () ->
  let conn = TestUtil.connect () in
  let _ = afterAll (fun () -> Sql.close conn) in
  let name = "Simple string interpolation query" in
  testPromise name (fun () -> Js.Promise.(
    let params = Some(
      `Anonymous (Json.Encode.array Json.Encode.string [|"%schema"|])
    ) in
    Sql.Promise.query conn ~sql:"SELECT ? AS search" ?params ()
    |> then_ (fun (rows, _) ->
        Belt_Array.map rows (fun x -> x |> decoder |> get_search)
        |> Expect.expect
        |> Expect.toBeSupersetOf [|"%schema"|]
        |> resolve
      )
  ))
);
