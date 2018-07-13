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
