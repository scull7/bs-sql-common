[![NPM](https://nodei.co/npm/bs-sql-common.png)](https://nodei.co/npm/bs-sql-common/)
[![Build Status](https://www.travis-ci.org/scull7/bs-sql-common.svg?branch=master)](https://www.travis-ci.org/scull7/bs-sql-common)
[![Coverage Status](https://coveralls.io/repos/github/scull7/bs-sql-common/badge.svg?branch=master)](https://coveralls.io/github/scull7/bs-sql-common?branch=master)

# bs-sql-common
A common interface for SQL-based Node.js drivers.

## Why?

To provide a common interface for MySQL, PostgreSQL and sqlite
implementations.  

### Version 3
A rewrite of the entire package to expose it as a Functor that can accept
any module which implements the [`Queryable`](#Queryable) interface.

* Use [Belt.Result][belt-result] for responses so to better integrate with then
  BuckleScript ecosystem.

* Provide [response decoding and inspection](#Sql.Response) functions so that
  the user has a consistent view into responses from any library.

* Provide an [ID type](#Sql.Id) that properly encodes large integers as strings.

* Provide batch inserts and queries

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
module Sql = SqlCommon.Make(MySql2)

let db = Sql.Connection.connect
  ~host="127.0.0.1"
  ~port=3306
  ~user="root"
  ()

Sql.query ~db ~sql:"SHOW DATABASES" (fun res ->
  match res with
  | Belt.Result.Error e -> raise e
  | Belt.Result.Ok select ->
    select
    |. Sql.Response.Select.mapDecoder (Json.Decode.dict Json.Decode.string)
    |. Belt.Array.map (fun x -> Js.dict.unsafeGet x "Database")
    |. Expect.expect
    |> Expect.toContain @@ "test"
)
```

## Usage

***Note:*** All of the examples use the [`bs-mysql2`][bs-mysql2] package as the
connection provider. Any other provider should have the same behavior with
differing connection creation requirements.

### Create a connection and customized module

The following connection and module will be use within the rest of the examples.
```reason
module Sql = SqlCommon.Make(MySql2);

let db = Sql.Connection.connect(~host="127.0.0.1", ~port=3306, ~user="root", ());
```
Assume the following statement occurs at the end of each example.
```reason
Sql.Connection.close(conn);
```

### Standard Callback Interface

#### Standard Query Method

```reason
Sql.query(~db, ~sql="SHOW DATABASES",
  fun
  | Belt.Result.Error e => Js.log2("ERROR: ", e)
  | Belt.Result.Ok select =>
    select
    |. Sql.Response.Select.rows
    |. Js.log2("RESPONSE ROWS: ", _)
);

Sql.mutate(
  ~db,
  ~sql="INSERT INTO test (foo) VALUES (?)",
  ~params=Sql.Params.positional(Json.Encode.([|string("bar")|] |. array)),
  (res) =>
    fun
    | Belt.Result.Error => Js.log2("ERROR: ", e)
    | Belt.Result.Ok mutation =>
      mutation
      |. Sql.Response.Mutation.insertId
      |. Js.log2("INSERT ID: ", _)
);
```

#### Prepared Statements - Named Placeholders

```reason
let json = Sql.Params.named(
  Json.Encode.(object_([
  ("x", int(1)),
  ("y", int(2)),
  ]))
));

let decoder = Json.Encode.array(Json.Encode.int)

Sql.query(~db, ~sql:"SELECT :x + :y AS z", ~params, (res) =>
  switch res {
  | Belt.Result.Error => Js.log2("ERROR: ", e)
  | Belt.Result.Ok select =>
    select
    |. Sql.Response.mapDecoder(decoder)
    |. Js.log2("DECODED ROWS: ", _)
  }
);

Sql.mutate(~db, ~sql:"INSERT INTO test (foo, bar) VALUES (:x, :y)", ~params, (res) =>
  switch res {
  | Belt.Result.Error => Js.log2("ERROR: ", e)
  | Belt.Result.Ok mutation =>
    mutation
    |. Sql.Response.Mutation.insertId
    |. Js.log2("INSERT ID: ", _)
  }
);
```

#### Prepared Statements - Positional Placeholders

```reason
let params = Sql.Params.positional(
  Json.Encode.(array(int, [|5,6|]))
));

Sql.query(~db, ~sql:"SELECT 1 + ? + ? AS result", ~params, (res) =>
  switch res {
  | Belt.Result.Error => Js.log2("ERROR: ", e)
  | Belt.Result.Ok select =>
    select
    |. Sql.Response.rows
    |. Js.log2("RAW ROWS: ", _)
  }
);

Sql.mutate(~db, ~sql:"INSERT INTO test (foo, bar) VALUES (?, ?)", ~params, (res) =>
  switch res {
  | Belt.Result.Error => Js.log2("ERROR: ", e)
  | Belt.Result.Ok mutation =>
    mutation
    |. Sql.Response.Mutation.insertId
    |. Js.log2("INSERT ID: ", _)
  }
);
```

### Promise Interface

```reason
let params = Sql.Params.positional(
  Json.Encode.(array(int, [|"%schema"|]))
));

Sql.query(~db, ~params, ~sql="SELECT ? AS search")
|> Js.Promise.then_(select =>
  select
  |. Sql.Response.rows
  |. Js.log2("RAW ROWS: ", _)
  |. ignore
)
|> Js.Promise.catch(err =>
  Js.log2("Failure!!!", err)
  |. ignore
)
```

## Sql.Id
```ocaml
module Id: sig
  type t = Driver.Id.t

  val fromJson : Js.Json.t -> Driver.Id.t

  val toJson : Driver.Id.t -> Js.Json.t

  val toString : Driver.Id.t -> string
end
```

## Sql.Response
```ocaml
module Response: sig
  module Mutation: sig
    val insertId : Driver.Mutation.t -> Id.t option

    val affectedRows: Driver.Mutation.t -> int
  end

  module Select: sig
    module Meta : sig
      val schema : Driver.Select.Meta.t -> string

      val name : Driver.Select.Meta.t -> string

      val table : Driver.Select.Meta.t -> string
    end

    val meta : Driver.Select.t -> Driver.Select.Meta.t array

    val concat : Driver.Select.t -> Driver.Select.t -> Driver.Select.t

    val count : Driver.Select.t -> int

    val flatMap :
      Driver.Select.t ->
      (Js.Json.t -> Driver.Select.Meta.t array -> 'a) ->
      'a array

    val mapDecoder : Driver.Select.t -> (Js.Json.t -> 'a) -> 'a array

    val rows : Driver.Select.t -> Js.Json.t array
  end
end
```

## Queryable Interface
```ocaml
module type Queryable = sig
  module Connection : sig
    type t

    val connect :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit -> t

    val close : t -> unit
  end

  module Exn : sig
    val fromJs : Js.Json.t -> exn
  end

  module Id : sig
    type t

    val fromJson : Js.Json.t -> t

    val toJson : t -> Js.Json.t

    val toString : t -> string
  end

  module Mutation : sig
    type t

    val insertId : t -> Id.t option

    val affectedRows : t -> int
  end

  module Params : sig
    type t

    val named : Js.Json.t -> t

    val positional : Js.Json.t -> t
  end

  module Select : sig
    type t

    module Meta : sig
      type t

      val schema : t -> string

      val name : t -> string

      val table : t -> string
    end

    val meta : t -> Meta.t array

    val concat : t -> t -> t

    val count : t -> int

    val flatMap : t -> (Js.Json.t -> Meta.t array -> 'a) -> 'a array

    val mapDecoder : t -> (Js.Json.t -> 'a) -> 'a array

    val rows : t -> Js.Json.t array
  end

  type response =
    [
    | `Error of exn
    | `Mutation of Mutation.t
    | `Select of Select.t
    ]

  type callback = response -> unit

  val execute : Connection.t -> string -> Params.t option -> callback -> unit
end
```

[belt-result]: https://bucklescript.github.io/bucklescript/api/Belt.Result.html
[bs-mysql2]: https://github.com/scull7/bs-mysql2
[mysql2-custom-streams]: https://github.com/sidorares/node-mysql2/tree/master/documentation/Extras.md
