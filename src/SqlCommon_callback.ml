module type Queryable = SqlCommon_queryable.Queryable

module Exn = SqlCommon_exn
module Sql = SqlCommon_sql

module Make (Driver: Queryable) = struct

  module Exn_response = Exn.Invalid.Response

  module Select = struct
    let raw db ?params ~sql cb =
      Driver.execute db sql params (fun res ->
      match res with
      | `Select select -> select |. Belt.Result.Ok |. cb
      | `Mutation _ -> Exn_response.expected_select |. Belt.Result.Error |. cb
      | `Error e -> e |. Belt.Result.Error |. cb
      )

    let query db ?params ~sql cb = raw db ~sql ?params cb
  end

  module Mutate = struct
    let raw db ?params ~sql cb =
      Driver.execute db sql params (fun res ->
        match res with
        | `Mutation mutation -> mutation |. Belt.Result.Ok |. cb
        | `Select _ -> Exn_response.expected_mutation |. Belt.Result.Error |. cb
        | `Error e -> e |. Belt.Result.Error |. cb
      )

    let run db ?params ~sql cb =
      match (Sql.contains_in sql) with
      | true -> Exn.Invalid.Query.illegal_use_of_in |. Belt.Result.Error |. cb
      | false -> raw db ~sql ?params cb
  end
end
