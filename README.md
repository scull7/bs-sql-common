[![NPM](https://nodei.co/npm/bs-sql-common.png)](https://nodei.co/npm/bs-sql-common/)
[![Build Status](https://www.travis-ci.org/scull7/bs-sql-common.svg?branch=master)](https://www.travis-ci.org/scull7/bs-sql-common)
[![Coverage Status](https://coveralls.io/repos/github/scull7/bs-sql-common/badge.svg?branch=master)](https://coveralls.io/github/scull7/bs-sql-common?branch=master)

# bs-sql-common
A common interface for SQL-based Node.js drivers.

## Why?

To provide a common interface for MySQL, PostgreSQL and sqlite
implementations.  

### Version 2
A rewrite of the entire package to expose it as a Functor that can accept
any module which implements the `Queryable` interface.

```ocaml
module type Queryable = sig
  type t
  type meta
  type rows = Js.Json.t array

  type params =
    [ `Named of Js.Json.t
    | `Anonymous of Js.Json.t
    ] option

  type callback = exn Js.Nullable.t -> Js.Json.t -> Js.Json.t array -> unit

  val close : t -> unit

  val parse_response :
    Js.Json.t ->
    Js.Json.t array ->
    [> `Error of exn
    |  `Mutation of int * int
    |  `Select of rows * meta
    ]

  val execute : t -> string -> params -> callback -> unit
end
```

The new interface provided through the Functor is simplified as it only contains
six methods and uses Polymorphic variants for return states so that the user no
longer requires structural knowledge of the SqlCommon package for response
parsing.

## Status

The standard things are there and this library is being used live within
several production projects.

- [x] Query parameter substitution
- [x] Named parameters
- [x] Promise based interface.
- [ ] Connection pooling
- [ ] [Custom Streams][mysql2-custom-streams]

## Installation

Inside of a BuckleScript project:
```sh
yarn install --save bs-sql-common
```

Then add `bs-sql-common` to your `bs-dependencies` in your `bsconfig.json`
```json
{
  "bs-dependencies": [ "bs-sql-common" ]
}
```

Then add a `bs-sql-common` compatible package to your repository or create your
own. All of the examples use the [`bs-mysql2`][bs-mysql2] package, here are the
requirements to use that package:

```sh
yarn install --save bs-mysql2Â
```
```json
{
  "bs-dependencies": [ "bs-sql-common", "bs-mysql2" ]
}
```
```ocaml
  module Db = SqlCommon.Make_store(MySql.Connection)

  let conn = MySql.Connection.make ~host="127.0.0.1" ~port=3306 ~user="root" ()

  Db.query conn ~sql:"SHOW DATABASES" (fun res ->
    match res with
    | `Error e -> Js.log2 "ERROR: " e
    | `Select (rows, meta) -> Js.log3 "SELECT: " rows meta
  )
```

## Usage

***Note:*** All of the examples use the [`bs-mysql2`][bs-mysql2] package as the
connection provider. Any other provider should have the same behavior with
differing connection creation requirements.

### Create a connection and customized module

The following connection and module will be use within the rest of the examples.
```reason
module Db = SqlCommon.Make_store(MySql.Connection);

let conn = MySql.Connection.make(~host="127.0.0.1", ~port=3306, ~user="root", ());
```
Assume the following statement occurs at the end of each example.
```reason
Db.close(conn);
```

### Standard Callback Interface

#### Standard Query Method

```reason

Db.query(~sql="SHOW DATABASES", (res) =>
  switch res {
  | `Error e => Js.log2("ERROR; ", e)
  | `Select (rows, meta) => Js.log3("SELECT: ", rows, meta)
  }
);

Db.mutate(~sql="INSERT INTO test (foo) VALUES (\"bar\")", (res) =>
  switch res {
  | `Error e => Js.log2("ERROR; ", e)
  | `Mutation (count, id) => Js.log3("MUTATION: ", count, id)
  }
)
```

#### Prepared Statements - Named Placeholders

```reason
let json = Some(`Named(
  Json.Encode.(object_([
  ("x", int(1)),
  ("y", int(2)),
  ]))
));

Db.query(~sql:"SELECT :x + :y AS z", ?params, (res) =>
  switch res {
  | `Error e => Js.log2("ERROR; ", e)
  | `Select (rows, meta) => Js.log3("SELECT: ", rows, meta)
  }
);

Db.mutate(~sql:"INSERT INTO test (foo, bar) VALUES (:x, :y)", ?params, (res) =>
  switch res {
  | `Error e => Js.log2("ERROR; ", e)
  | `Mutation (count, id) => Js.log3("MUTATION: ", count, id)
  }
)
```

#### Prepared Statements - Positional Placeholders

```reason
let params = Some(`Anonymous(
  Json.Encode.(array(int, [|5,6|]))
));

Db.query(~sql:"SELECT 1 + ? + ? AS result", ?params, (res) =>
  switch res {
  | `Error e => Js.log2("ERROR; ", e)
  | `Select (rows, meta) => Js.log3("SELECT: ", rows, meta)
  }
);

Db.mutate(~sql:"INSERT INTO test (foo, bar) VALUES (?, ?)", ?params, (res) =>
  switch res {
  | `Error e => Js.log2("ERROR; ", e)
  | `Mutation (count, id) => Js.log3("MUTATION: ", count, id)
  }
)
```

### Promise Interface

```reason
let params = Some(`Anonymous(
  Json.Encode.(array(int, [|"%schema"|]))
));
Db.query(conn, ~sql="SELECT ? AS search", ?params)
|> Js.Promise.then_(((rows, meta)) => {
  Js.log3("SELECT: ", rows, meta);
  Db.close(conn);
  Js.Promise.resolve(1);
})
|> Js.Promise.catch((err) => {
  Js.log2("Failure!!!", err);
  Db.close(conn);
  Js.Promise.resolve(-1);
});
```

[bs-mysql2]: https://github.com/scull7/bs-mysql2
[mysql2-custom-streams]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Extras.md
