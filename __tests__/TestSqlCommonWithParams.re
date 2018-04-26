open Jest;

module Sql = SqlCommon.Make_sql(MySql2);

type result = {
  result: int,
};

let get_result = ({
  result,
}) => result;

let expect = (name, value, decoder, next, res) =>
  switch res {
  | `Error(e) => {
      Js.log2(name, e);
      fail({j|ERROR: $name|j}) |> next
    }
  | `Select (rows, _) =>
    Belt_Array.map(rows, x => x |> decoder |> get_result)
    |> Expect.expect
    |> Expect.toBeSupersetOf([|value|])
    |> next
  };

describe("Test parameter interpolation", () => {
  let conn = TestUtil.connect();
  afterAll(() => conn |> Sql.close);

  let decoder = json =>
    Json.Decode.{
      result: json |> field("result", int),
    };

  describe("Standard (positional) parameters", () => {
    let name = "Expect parameters to be substituted properly";
    testAsync(name, finish => {
      let next = expect(name, 12, decoder, finish);
      let params = Some(
        `Positional(
          Json.Encode.array(Json.Encode.int, [|5, 6|])
        )
      );
      Sql.query(conn, ~sql="SELECT 1 + ? + ? AS result", ~params?, next)
    })
  });

  describe("Named parameters", () => {
    let name = "Expect parameters to be substituted properly";
    testAsync(name, finish => {
      let next = expect(name, 3, decoder, finish);
      let params = Some(
        `Named(
          Json.Encode.object_([
            ("x", Json.Encode.int(1)),
            ("y", Json.Encode.int(2)),
          ])
        )
      );
      Sql.query(conn, ~sql="SELECT :x + :y AS result", ~params?, next)
    });
  });
});
