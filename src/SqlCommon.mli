module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable): sig

  module Connection: sig
    val close: Driver.Connection.t -> unit

    val connect :
      ?host:string ->
      ?port:int ->
      ?user:string ->
      ?password:string ->
      ?database:string ->
      unit -> Driver.Connection.t

  end

  module Batch: sig
    module Mutate: sig
      (*
      val start :
        Driver.Connection.t ->
        ?batch_size:int ->
        table:string ->
        columns: Js.Json.t ->
        rows:Js.Json.t ->
        ([> | `Error of exn | `Count of int] -> unit) ->
        unit
        *)
    end

    module Query: sig
    end
  end
end
