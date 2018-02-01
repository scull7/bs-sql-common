![Project Status](https://img.shields.io/badge/status-alpha-red.svg)

# bs-mysql2
ReasonML bindings to the [mysql2] library.

This is a very rough implementation that will enable very simple use cases.

Initially this was just a copy of [bs-mysql].

## Why?

The main difference between these bindings and the [bs-mysql] bindings is the
use of the [mysql2] library / driver over the [mysql] (version 1) driver. You
can see the reasoning behind the new [mysql2] driver here:
[History and Why MySQL2][mysql2-features]

Also, hopefully, the interface presented feels more conventional
for ReasonmML / OCaml

## Status

Not all of the [mysql2] library [features][mysql2-features] are implemented but
there is a usable implementation of the [Promise based wrapper](#promise-interface)
and [Named Placeholders](#named-placeholders).

 - [x] Faster / Better Performance (_kind of get this for free_)
 - [x] [Prepared Statements][mysql2-prepared-statements] - [examples](#prepared-statements)*
 - [ ] MySQL Binary Log Protocol
 - [ ] [MySQL Server][mysql2-server]
 - [ ] Extended support for Encoding and Collation
 - [x] [Promise Wrapper][mysql2-promise] - [examples](#promise-interface)*
 - [ ] Compression
 - [ ] SSL and [Authentication Switch][mysql2-auth-switch]
 - [ ] [Custom Streams][mysql2-custom-streams]
 - [ ] Pooling

 _* incomplete but usable implementation_

## Usage

### Standard Callback Interface

#### Standard Query Method
```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let _ = MySql.raw conn "SHOW DATABASES" (fun r ->
  match r with
  | Response.Error e -> Js.log2 "ERROR: " e
  | Response.Select s -> Js.log2 "SELECT: " s
  | Response.Mutation m -> Js.log2 "MUTATION: " m
)

let _ = MySql.Connection.close conn
```

#### Prepared Statements

##### Named Placeholders
```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let logThenClose label x =
  let _ = Js.log2 label x in
  MySql.Connection.close conn

let sql2 = "SELECT :x + :y as z"
let params2 = [%bs.obj {x = 1; y = 2}]
let _ = MySql.with_named_params conn sql2 params2 (fun r ->
  match r with
  | Response.Error e -> logThenClose "ERROR: " e
  | Response.Select s -> logThenClose "SELECT: " s
  | Response.Mutation m -> logThenClose "MUTATION: " m
)
```

```reason
let conn =
  MySql.Connection.make(~host="127.0.0.1", ~port=3306, ~user="root", ());

MySql.with_named_params(conn, "SELECT :x + :y as z", {"x": 1, "y": 2}, result =>
  switch result {
  | Error(e) => Js.log2("ERROR: ", e)
  | Mutation(m) => Js.log2("MUTATION: ", m)
  | Select(s) => Js.log2("SELECT: ", s)
  }
);

MySql.Connection.close(conn);
```

##### Unnamed Placeholders
```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let logThenClose label x =
  let _ = Js.log2 label x in
  MySql.Connection.close conn

let _ = MySql.with_params conn "SELECT 1 + ? + ? as result" [|5; 6|] (fun r ->
  match r with
  | Response.Error e -> logThenClose "ERROR: " e
  | Response.Select s -> logThenClose "SELECT: " s
  | Response.Mutation m -> logThenClose "MUTATION: " m
)
```

### Promise Interface
```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let _ = Js.Promise.resolve(conn)
|> MySql.Promise.pipe_with_params "SELECT ? as search" [| "%schema" |]
|> Js.Promise.then_ (fun value ->
    let _ = Js.log value in
    Js.Promise.resolve(1)
  )
|> MySql.Connection.Promise.close conn
|> Js.Promise.catch (fun err ->
    let _ = Js.log2("Failure!!!", err) in
    let _ = MySql.Connection.close conn in
    Js.Promise.resolve(-1)
  )
```

## How do I install it?

Inside of a BuckleScript project:
```shell
yarn install --save bs-mysql2
```

Then add `bs-mysql2` to your `bs-dependencies` in `bsconfig.json`:
```json
{
  "bs-dependencies": [
    "bs-mysql2"
  ]
}
```

## How do I use it?

### Use it in your project
See the [Usage](#usage) section above...

### Run the examples
```shell
yarn run examples:simple
```
```shell
yarn run examples:promise
```
```shell
yarn run examples:prepared-statements
```

## What's missing?

Mostly everything...

[bs-mysql]: https://github.com/davidgomes/bs-mysql
[mysql]: https://www.npmjs.com/package/mysql
[mysql2]: https://www.npmjs.com/package/mysql2
[mysql2-features]: https://github.com/sidorares/node-mysql2#history-and-why-mysql2
[mysql2-prepared-statements]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Prepared-Statements.md
[mysql2-server]: https://github.com/sidorares/node-mysql2/tree/master/documentation/MySQL-Server.md
[mysql2-promise]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Promise-Wrapper.md
[mysql2-auth-switch]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Authentication-Switch.md
[mysql2-custom-streams]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Extras.md
