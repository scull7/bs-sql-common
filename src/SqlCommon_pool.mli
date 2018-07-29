module type Queryable = SqlCommon_queryable.Queryable

module type Pool = sig

  type t = Tarn.t

  val make :
    ?min:int ->
    ?max:int ->
    ?acquireTimeoutMillis:int ->
    ?createTimeoutMillis:int ->
    ?idleTimeoutMillis:int ->
    ?reapIntervalMillis:int ->
    ?propagateCreateError:bool ->
    ?host:string ->
    ?port:int ->
    ?user:string ->
    ?password:string ->
    ?database:string ->
    unit -> t

  val acquire : t -> ('a, exn) Belt.Result.t Js.Promise.t

  val destroy : t -> unit Js.Promise.t

  val release : t -> 'a -> unit

  val numUsed : t -> int

  val numFree : t -> int

  val numPendingAcquires : t -> int

  val numPendingCreates : t -> int

end

module Make(Driver: Queryable): Pool
