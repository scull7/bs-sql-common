open Jest

module Sql = TestUtil.Sql

type result = {
  search: string;
}

let get_search { search } = search

let decoder json = Json.Decode.({ search = json |> field "search" string; })

let () =

describe "Test Promise based API" (fun () ->
  let db = TestUtil.connect () in
  let _ = afterAll (fun () -> Sql.Connection.close db) in

  testPromise "Simple string interpolation query" (fun () -> Js.Promise.(
    let params =
      Json.Encode.array Json.Encode.string [| "%schema" |]
      |. Sql.Params.named
      |. Some
    in
    Sql.Promise.query ~db ?params ~sql:"SELECT ? AS search"
    |> then_ (fun select ->
        select
        |. Sql.Response.Select.flatMap (fun x -> x |. decoder |. get_search)
        |. resolve
    )
    |> then_ (fun rows ->
        Expect.expect rows
        |> Expect.toBeSupersetOf [| "%schema" |]
        |> resolve
    )
  ))
);
