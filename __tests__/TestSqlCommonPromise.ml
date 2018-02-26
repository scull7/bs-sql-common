open Jest

type result = {
  search: string;
}

let get_search { search } = search

let decoder json = Json.Decode.({ search = json |> field "search" string; })

let () =

describe "Test Promise based API" (fun () ->
  let conn = TestUtil.connect () in
  testPromise "Simple string interpolation query" (fun () -> Js.Promise.(
    resolve conn
    |> SqlCommon.Promise.pipe_with_params "SELECT ? AS search" [|"%schema"|]
    |> then_ (fun results ->
      match results with
      | SqlCommon.Promise.Result.Mutation _ -> failwith "unexpected_mutation"
      | SqlCommon.Promise.Result.Select { rows; _ } ->
        Belt_Array.map rows (fun x -> x |> decoder |> get_search)
        |> Expect.expect
        |> Expect.toBeSupersetOf [|"%schema"|]
        |> resolve
    )
  ))
);
