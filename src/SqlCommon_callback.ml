module type Queryable = SqlCommon_queryable.Queryable

module Exn = SqlCommon_exn
module Sql = SqlCommon_sql

module Make (Driver: Queryable) = struct
  let close = Driver.Connection.close
  let connect = Driver.Connection.connect

  module Select = struct
    let raw db ?params ~sql cb =
      Driver.execute db sql params (fun res ->
      match res with
      | `Select select -> cb (`Select select)
      | `Mutation _ -> cb (`Error Exn.Invalid.Response.expected_select)
      | `Error e -> cb (`Error e)
      )

    let query db ?params ~sql cb = raw db ~sql ?params cb
  end

  module Mutate = struct
    let raw db ?params ~sql cb =
      Driver.execute db sql params (fun res ->
        match res with
        | `Mutation mutation -> cb (`Mutation mutation)
        | `Select _ -> cb (`Error Exn.Invalid.Response.expected_mutation)
        | `Error e -> cb (`Error e)
      )

    let run db ?params ~sql cb =
      match (Sql.contains_in sql) with
      | true -> cb (`Error Exn.Invalid.Query.illegal_use_of_in)
      | false -> raw db ~sql ?params cb
  end
end
