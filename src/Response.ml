type sql = string

type response =
  | Mutation of Result.mutation
  | Select of Result.select
  | Error of exn
