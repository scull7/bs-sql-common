module type Queryable = SqlCommon_queryable.Queryable

module type Pool = sig

  type t

  type connection

  val acquire : t -> connection Js.Promise.t

  val destroy : t -> unit Js.Promise.t

  val release : t -> connection -> unit Js.Promise.t

end

module Make(Driver: Queryable): Pool
  with type t = Driver.Pool.t
  with type connection = Driver.Connection.t
