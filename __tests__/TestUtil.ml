
let env = Node.Process.process##env
let host = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_HOST") "localhost"
let port = int_of_string (Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_PORT") "3306")
let user = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_USER") "root"
let password = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_PASSWORD") "password"
let database = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_DATABASE") "test"

let connect _ = MySql2.connect
  ~host
  ~port
  ~user
  ~password
  ~database
  ()
