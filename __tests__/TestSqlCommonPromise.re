open Jest;

module Sql = SqlCommon.Make_sql(MySql2);

type result = {
  search: string,
};

let get_search = ({
  search,
}) => search;

let decoder = json =>
  Json.Decode.{
    search: json |> field("search", string),
  };

describe("Test Promise based API", () => {
  let conn = TestUtil.connect();
  afterAll(() => conn |> Sql.close);

  testPromise("Simple string interpolation query", () => {
    open Js.Promise;
    let params = Some(
      `Positional(
        Json.Encode.array(Json.Encode.string, [|"%schema"|])
      )
    );

    Sql.Promise.query(conn, ~sql="SELECT ? AS search", ~params?, ())
    |> then_(
      ((rows, _)) =>
        Belt_Array.map(rows, x => x |> decoder |> get_search)
        |> Expect.expect
        |> Expect.toBeSupersetOf([|"%schema"|])
        |> resolve
    );
  })
});
