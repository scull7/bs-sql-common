[![NPM](https://nodei.co/npm/bs-sql-common.png)](https://nodei.co/npm/bs-sql-common/)
[![Build Status](https://www.travis-ci.org/scull7/bs-sql-common.svg?branch=master)](https://www.travis-ci.org/scull7/bs-sql-common)
[![Coverage Status](https://coveralls.io/repos/github/scull7/bs-sql-common/badge.svg?branch=master)](https://coveralls.io/github/scull7/bs-sql-common?branch=master)

# bs-sql-wrapper
A common interface for SQL-based Node.js drivers.

## Why?

To provide a common interface for MySQL, PostgreSQL and sqlite
implementations.  

Hopefully the interface presented feels conventional for ReasonML / OCaml.

## Status

The standard things are there and this library is being used live within
several production projects.

- [x] Query parameter substitution
- [x] Named parameters
- [x] Promise based interface.
- [ ] Connection pooling
- [ ] [Custom Streams][mysql2-custom-streams]

## Usage

In all of the examples the [bs-mysql2] bindings are used, however,
it should be the same with any SqlCommon compatible driver bindings.

### Standard Callback Interface

#### Standard Query Method

##### Reason syntax

```reason
let conn = MySql.Connection.make(~host="127.0.0.1", ~port=3306, ~user="root", ());

SqlCommon.raw(
  conn,
  "SHOW DATABASES",
  (r) =>
    switch r {
    | Response.Error(e) => Js.log2("ERROR: ", e)
    | Response.Select(s) => Js.log2("SELECT: ", s)
    | Response.Mutation(m) => Js.log2("MUTATION: ", m)
    }
);

MySql.Connection.close(conn);
```

##### OCaml syntax

```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let _ = SqlCommon.raw conn "SHOW DATABASES" (fun r ->
  match r with
  | Response.Error e -> Js.log2 "ERROR: " e
  | Response.Select s -> Js.log2 "SELECT: " s
  | Response.Mutation m -> Js.log2 "MUTATION: " m
)

let _ = MySql.Connection.close conn
```

#### Prepared Statements - Named Placeholders

##### Reason syntax

```reason
let conn =
  MySql.Connection.make(~host="127.0.0.1", ~port=3306, ~user="root", ());

SqlCommon.with_named_params(conn, "SELECT :x + :y as z", {"x": 1, "y": 2}, result =>
  switch result {
  | Error(e) => Js.log2("ERROR: ", e)
  | Mutation(m) => Js.log2("MUTATION: ", m)
  | Select(s) => Js.log2("SELECT: ", s)
  }
);

MySql.Connection.close(conn);
```

##### OCaml syntax

```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let logThenClose label x =
  let _ = Js.log2 label x in
  MySql.Connection.close conn

let sql2 = "SELECT :x + :y as z"
let params2 = [%bs.obj {x = 1; y = 2}]
let _ = SqlCommon.with_named_params conn sql2 params2 (fun r ->
  match r with
  | Response.Error e -> logThenClose "ERROR: " e
  | Response.Select s -> logThenClose "SELECT: " s
  | Response.Mutation m -> logThenClose "MUTATION: " m
)
```

#### Prepared Statements - Un-named Placeholders

##### Reason syntax

```reason
let conn = MySql.Connection.make(~host="127.0.0.1", ~port=3306, ~user="root", ());

let logThenClose = (label, x) => {
  let _ = Js.log2(label, x);
  MySql.Connection.close(conn)
};

SqlCommon.with_params(
  conn,
  "SELECT 1 + ? + ? as result",
  [|5, 6|],
  (r) =>
    switch r {
    | Response.Error(e) => logThenClose("ERROR: ", e)
    | Response.Select(s) => logThenClose("SELECT: ", s)
    | Response.Mutation(m) => logThenClose("MUTATION: ", m)
    }
);
```

##### OCaml syntax

```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let logThenClose label x =
  let _ = Js.log2 label x in
  MySql.Connection.close conn

let _ = SqlCommon.with_params conn "SELECT 1 + ? + ? as result" [|5; 6|] (fun r ->
  match r with
  | Response.Error e -> logThenClose "ERROR: " e
  | Response.Select s -> logThenClose "SELECT: " s
  | Response.Mutation m -> logThenClose "MUTATION: " m
)
```

### Promise Interface

##### Reason syntax

```reason
let conn = MySql.Connection.make(~host="127.0.0.1", ~port=3306, ~user="root", ());

Js.Promise.resolve(conn)
|> SqlCommon.Promise.pipe_with_params("SELECT ? as search", [|"%schema"|])
|> Js.Promise.then_(
     (value) => {
       let _ = Js.log(value);
       Js.Promise.resolve(1)
     }
   )
|> MySql.Connection.Promise.close(conn)
|> Js.Promise.catch(
     (err) => {
       let _ = Js.log2(("Failure!!!", err));
       let _ = MySql.Connection.close(conn);
       Js.Promise.resolve((-1))
     }
   );
```

##### Ocaml syntax

```ocaml
let conn = MySql.Connection.make ~host:"127.0.0.1" ~port:3306 ~user:"root" ()

let _ = Js.Promise.resolve(conn)
|> SqlCommon.Promise.pipe_with_params "SELECT ? as search" [| "%schema" |]
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

[bs-mysql2]: https://github.com/scull7/bs-mysql2
[mysql2-custom-streams]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Extras.md
