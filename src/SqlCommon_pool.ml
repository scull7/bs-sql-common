
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

module Make(Driver: Queryable): Pool with type t = Tarn.t = struct
  
  type t = Tarn.t

  let make
    ?min
    ?max
    ?acquireTimeoutMillis
    ?createTimeoutMillis
    ?idleTimeoutMillis
    ?reapIntervalMillis
    ?propagateCreateError
    ?host
    ?port
    ?user
    ?password
    ?database
    _
  =
    let create = (fun cb ->
      let c = Driver.Connection.connect ?host ?port ?user ?password ?database ()
      in
      cb Js.Nullable.null (Js.Nullable.return c)
    )
    in
    let validate _ = true
    in
    let destroy connection = Driver.Connection.close connection
    in
    Tarn.make
      ?min
      ?max
      ?acquireTimeoutMillis
      ?createTimeoutMillis
      ?idleTimeoutMillis
      ?reapIntervalMillis
      ?propagateCreateError
      ~create
      ~validate
      ~destroy
      ()

  let acquire = Tarn.acquire

  let destroy = Tarn.destroy

  let release = Tarn.release

  let numUsed = Tarn.numUsed

  let numFree = Tarn.numFree

  let numPendingAcquires = Tarn.numPendingAcquires

  let numPendingCreates = Tarn.numPendingCreates

end
