
module Sql = SqlCommon.Make(MySql2)

let connect _ = Sql.Connection.connect
  ~host:"127.0.0.1"
  ~port:3306
  ~user:"root"
  ()

let mutate db sql next =
  Sql.mutate ~db ~sql (fun res ->
    match res with
    | Belt.Result.Error e -> e |. Js.String.make |. failwith
    | Belt.Result.Ok _ -> next ()
  )
  |. ignore

let drop db table next =
  let sql = {j|DROP TABLE IF EXISTS `test`.`$table`|j}
  in
  mutate db sql next

let drop_test_simple db next = drop db "simple" next

let create_test_simple db next =
  let sql = {|
    CREATE TABLE IF NOT EXISTS test.simple (
      `id` bigint(20) NOT NULL AUTO_INCREMENT
    , `code` varchar(32) NOt NULL
    , PRIMARY KEY(`id`)
    )
  |}
  in
  mutate db sql next

let insert_initial_test_simple db next =
  let sql = {|
    INSERT INTO test.simple
    (code)
    VALUES
    ("foo"), ("bar"), ("baz")
  |}
  in
  mutate db sql next

let init_test_simple db next =
  drop_test_simple db (fun _ ->
    create_test_simple db (fun _ ->
      insert_initial_test_simple db next
    )
  )
