open Jest

module Sql = TestUtil.Sql

let () =

describe "Pool Async methods" (fun () ->

  let pool = TestUtil.pool() in

  let _ = afterAllPromise (fun () -> Sql.Pool.destroy pool) in

  testPromise "acquire" (fun () ->
    let sql = "SELECT 21 + 21 AS the_answer" in

    let decoder = Json.Decode.(field "the_answer" int) in

    let then_release db = Js.Promise.then_ (fun x ->
      let _ = Sql.Pool.release pool db in
      Js.Promise.resolve x
    )
    in
    pool
    |> Sql.Pool.acquire
    |> Js.Promise.then_ (fun db ->
        Sql.Promise.query ~db ~sql ?params:None
        |> then_release db
    )
    |> Js.Promise.then_ (fun select ->
      select
      |. Sql.Response.Select.flatMap decoder
      |. Belt.Array.getExn 0
      |> Expect.expect
      |> Expect.toBe(42)
      |> Js.Promise.resolve
    )
    |> Js.Promise.catch (fun e ->
      e |. Js.String.make |. fail |. Js.Promise.resolve
    )
  )
)
