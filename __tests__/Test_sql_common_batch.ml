open Jest

module Sql = TestUtil.Sql

let table = "test.sql_common_batch"

let table_sql = {j|
  CREATE TABLE IF NOT EXISTS $table (
    `id` bigint(20) NOT NULL AUTO_INCREMENT
  , `code` varchar(32) NOT NULL
  , `desc` varchar(10) NOT NULL
  , PRIMARY KEY(id)
  , UNIQUE KEY (`code`)
  )
|j}

let initialize db next =
  TestUtil.drop db "sql_common_batch" (fun _ -> TestUtil.mutate db table_sql next)

let single_run_rows = Json.Encode.([|
  jsonArray [| (string "yankees"); (string "mlb") |];
  jsonArray [| (string "buckeyes"); (string "ncaa") |];
  jsonArray [| (string "steelers"); (string "nfl") |];
|])

let multiple_run_rows = Json.Encode.([|
  jsonArray [| (string "juventas"); (string "fifa") |];
  jsonArray [| (string "caviliers"); (string "nba") |];
  jsonArray [| (string "49ers"); (string "nfl") |];
  jsonArray [| (string "bulls"); (string "nba") |];
  jsonArray [| (string "penguins"); (string "ncaa") |];
  jsonArray [| (string "golden_knights"); (string "nhl") |];
  jsonArray [| (string "colts"); (string "nfl") |];
  jsonArray [| (string "saints"); (string "nfl") |];
  jsonArray [| (string "indians"); (string "mlb") |];
  jsonArray [| (string "browns"); (string "nfl") |];
|])

let callback_run_rows = Json.Encode.([|
  jsonArray [| (string "crew"); (string "mls") |];
  jsonArray [| (string "real"); (string "mls") |];
  jsonArray [| (string "fire"); (string "mls") |];
  jsonArray [| (string "impact"); (string "mls") |];
|])

let failure_run_rows = Json.Encode.([|
  jsonArray [| (string "stampeders"); (string "cfl") |];
  jsonArray [| (string "roughriders"); (string "cfl") |];
  jsonArray [| (string "eskimos"); (string "cfl") |];
  jsonArray [| (string "eskimos"); (string "failure") |];
  jsonArray [| (string "argonauts"); (string "cfl") |];
  jsonArray [| (string "alouettes"); (string "cfl") |];
|])

let columns = [| "code"; "desc"; |]

type row = {
  id: Sql.Id.t;
  code: string;
  desc: string;
}

let decoder json = Json.Decode.{
  id = json |> field "id" Sql.Id.fromJson;
  code = json |> field "code" string;
  desc = json |> field "desc" string;
}

let () =

describe "SqlCommon :: Batch" (fun () ->
  let db = TestUtil.connect()
  in
  let _ = afterAll (fun () -> Sql.Connection.close db)
  in
  let _ = beforeAllAsync (fun next -> initialize db next)
  in
  describe "Callback" (fun () ->
    testPromise "Should insert rows in a single batch" (fun () ->
      Js.Promise.make (fun ~resolve ~reject ->
        Sql.Batch.mutate ~db ~table ~columns ~rows:callback_run_rows (fun res ->
          match res with
          | Belt.Result.Error e -> reject e [@bs]
          | Belt.Result.Ok int ->
            Expect.expect int
            |> Expect.toBe 4
            |> (fun x -> resolve x [@bs])
            |> ignore
        )
      )
    )
  );

  describe "Promise" (fun () ->
    testPromise "Should rollback" (fun () ->
      Sql.Promise.Batch.mutate ~db ~table ~columns ~rows:failure_run_rows ()
      |> Js.Promise.then_ (fun _ ->
        "unexpected success" |. fail |. Js.Promise.resolve
      )
      |> Js.Promise.catch (fun _ ->
        let sql = {j|SELECT * FROM $table WHERE `desc` = ?|j} in
        let params = Sql.Params.positional (
          Json.Encode.jsonArray [| Json.Encode.string "cfl" |]
        )
        in
        Sql.Promise.query ~db ~params ~sql
        |> Js.Promise.then_ (fun select ->
            Sql.Response.Select.rows select
            |. Belt.Array.length
            |. Expect.expect
            |> Expect.toBe 0
            |> Js.Promise.resolve
        )
      )
    );

    testPromise "Should insert rows in a single batch" (fun () ->
      Sql.Promise.Batch.mutate ~db ~table ~columns ~rows:single_run_rows ()
      |> Js.Promise.then_ (fun int ->
         Expect.expect int
         |> Expect.toBe 3
         |> Js.Promise.resolve
      )
    );

    testPromise "Should insert rows in multiple batches" (fun () ->
      Sql.Promise.Batch.mutate
        ~db
        ~batch_size:3
        ~table
        ~columns
        ~rows:multiple_run_rows
        ()
      |> Js.Promise.then_ (fun int ->
        Expect.expect int
        |> Expect.toBe 10
        |> Js.Promise.resolve
      )
    );

    testPromise "Should error on invalid syntax" (fun () ->
      let params = `Positional(
        [| "mlb"; "ncaa"; "nfl"; "nba"; "fifa" |]
        |. Belt.Array.map Json.Encode.string
      )
      in
      Sql.Promise.Batch.query
        ~db
        ~sql:{j|SELECT * FROM $table WHERE `unknown` IN (?) |j}
        ~params
        ()
      |> Js.Promise.then_ (fun _ ->
        "unexpected success" |. fail |. Js.Promise.resolve
      )
      |> Js.Promise.catch (fun e ->
        Js.String.make e
        |> Expect.expect
        |> Expect.toMatchRe [%re "/ER_BAD_FIELD_ERROR/"]
        |> Js.Promise.resolve
      )
    );

    testPromise "Should error on an empty parameter set" (fun () ->
      let params = `Positional([||] |. Belt.Array.map Json.Encode.string)
      in
      Sql.Promise.Batch.query
        ~db
        ~sql:{j|SELECT * FROM $table WHERE `unknown` IN (?) |j}
        ~params
        ()
      |> Js.Promise.then_ (fun _ ->
        "unexpected success" |. fail |. Js.Promise.resolve
      )
      |> Js.Promise.catch (fun e ->
        Js.String.make e
        |> Expect.expect
        |> Expect.toMatchRe [%re "/nil response/"]
        |> Js.Promise.resolve
      )
    );

    testPromise "Should select in multiple batches" (fun () ->
      let params = `Positional(
        [| "mlb"; "ncaa"; "nfl"; "nba"; "fifa" |]
        |. Belt.Array.map Json.Encode.string
      )
      in
      let expected = Js.Array.sortInPlace [|
        "yankees";
        "buckeyes";
        "steelers";
        "juventas";
        "caviliers";
        "49ers";
        "bulls";
        "penguins";
        "colts";
        "saints";
        "indians";
        "browns";
      |]
      in
      Sql.Promise.Batch.query
        ~db
        ~batch_size:2
        ~sql:{j| SELECT * FROM $table WHERE `desc` IN(?) |j}
        ~params
        ()
      |> Js.Promise.then_ (fun select ->
        select
        |. Sql.Response.Select.flatMap decoder
        |. Belt.Array.map (fun x -> x.code)
        |. Js.Array.sortInPlace
        |. Expect.expect
        |> Expect.toEqual expected
        |. Js.Promise.resolve
      )
    );
  )
)

