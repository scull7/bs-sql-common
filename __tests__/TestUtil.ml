
let env = Node.Process.process##env

let host = Js.Dict.get env "MYSQL_HOST"
let _ = Js.Console.log2 "host=" host

let host = Belt.Option.getWithDefault host "localhost"
let _ = Js.Console.log2 "host=" host

let port = int_of_string (Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_PORT") "3306")
let _ = Js.Console.log2 "port=" port

let user = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_USER") "root"
let _ = Js.Console.log2 "user=" user

let password = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_PASSWORD") "password"
let _ = Js.Console.log2 "password=" password

let database = Belt.Option.getWithDefault (Js.Dict.get env "MYSQL_DATABASE") "database"
let _ = Js.Console.log2 "database=" database

let connect _ = MySql2.connect
  ~host
  ~port
  ~user
  ~password
  ~database
  ()
