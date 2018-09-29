let debug = Debug.make "bs-sql-common" "pool"

exception PoolError of string

module PoolExn = struct
  let no_exn_no_conn _ = PoolError
    {|Could not retrieve connection, failed without error code.|}
end

module type Queryable = SqlCommon_queryable.Queryable

module type Pool = sig
  type t

  type connection

  (*
   * Eliminating the pool creation because the underlying pool
   * because each driver will have it's own pooling mechanism
   * which will have different construction requirements.
   *)

  val acquire : t -> connection Js.Promise.t

  val destroy : t -> unit Js.Promise.t

  val release : t -> connection -> unit Js.Promise.t
end

module Make(Driver: Queryable): Pool
  with type t = Driver.Pool.t
  with type connection = Driver.Connection.t
= struct
  type t = Driver.Pool.t

  type connection = Driver.Connection.t

  let acquire pool = Js.Promise.make (fun ~resolve ~reject ->
    let _ = debug {|ACQUIRE :: START|} in
    Driver.Pool.getConnection pool (fun maybe_exn maybe_conn ->
      let option_exn = Js.Null_undefined.toOption maybe_exn in
      let option_conn = Js.Null_undefined.toOption maybe_conn in
      match (option_exn, option_conn) with
      | (None, None) ->
          let _ = debug {|ACQUIRE :: ERROR :: UNKOWN :: empty reason |} in
          reject (PoolExn.no_exn_no_conn ()) [@bs]
      | (Some(exn), None) ->
          let exn_string = Js.String.make exn in
          let _ = debug {j|ACQUIRE :: ERROR :: $exn_string |j}
          in
          reject (PoolError exn_string) [@bs]
      | (Some(exn), Some(_)) ->
          let exn_string = Js.String.make exn in
          let _ = debug {j|ACQUIRE :: ERROR :: CONN_RECEIVED :: $exn_string |j}
          in
          reject (PoolError exn_string) [@bs]
      | (None, Some(conn)) ->
          let _ = debug {j|ACQUIRE :: SUCCESS|j}
          in
          resolve conn [@bs]
    )
  )

  let release _ conn = Js.Promise.make (fun ~resolve ~reject:_ ->
    let _ = debug {|RELEASE :: START|} in
    let _ = Driver.Pool.release conn in
    let _ = debug {|RELEASE :: SUCCESS|} in
    let nothing = ()
    in
    resolve nothing [@bs]
  )

  let destroy pool = Js.Promise.make (fun ~resolve ~reject ->
    let _ = debug {|DESTROY :: START|}
    in
    Driver.Pool.drain pool (fun maybe_exn ->
      match (maybe_exn |> Js.Null_undefined.toOption) with
      | None ->
          let _ = debug {|DESTROY :: SUCCESS |} in
          let nothing = () in
          let _ = resolve nothing [@bs]
          in ()
      | Some(exn) ->
          let exn_string = Js.String.make exn in
          let _ = debug {j|DESTROY :: ERROR :: $exn_string|j}
          in
          reject (PoolError exn_string) [@bs]
    )
  )
end
