let size setting = Belt.Option.getWithDefault setting 1000

let slice size rows =
  (
    Belt.Array.slice rows ~offset:0 ~len:size,
    Belt.Array.slice rows ~offset:size ~len:(Belt.Array.length rows)
  )

let trampoline fn = Js.Global.setTimeout fn 0

module Sql = struct
  (*
    Have to use this because MySQL2 doesn't properly
    handle the table name escaping
   *)
  let insert table columns rows =
    SqlCommon_sql.format
      {j| INSERT INTO $table (??) VALUES ?|j}
      [| columns; rows |]
end
