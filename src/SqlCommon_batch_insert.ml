module Batch = SqlCommon_batch
module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct

  let execute ~driver ~sql resolver =
    let _ = driver ~sql (fun response ->
      match response with
      | `Error error -> error |. Belt.Result.Error |. resolver
      | `Mutation m ->
          m
          |. Driver.Mutation.affectedRows
          |. Belt.Result.Ok
          |. resolver
    )
    in ()

  let rollback ~error ~driver resolver =
    execute ~driver ~sql:"ROLLBACK" (fun res ->
      match res with
      | Belt.Result.Error error -> error |. Belt.Result.Error |. resolver
      | Belt.Result.Ok _ -> error |. Belt.Result.Error |. resolver
    )

  let commit ~count ~driver resolver =
    execute ~driver ~sql:"COMMIT" (fun res ->
      match res with
      | Belt.Result.Error error -> rollback ~error ~driver resolver
      | Belt.Result.Ok _ -> count |. Belt.Result.Ok |. resolver
    )

  (*
   * ## Iterate
   * Handle a single iteration.  This function automatically bounces
   * out of synchronous execution in case we have a driver which is 
   * inherently synchronous.
   *)
  let iterate ~count ~insert ~batch_size ~rows next =
    let ( current, rest ) = Batch.slice batch_size rows in
    (* Trampoline, in case the connection driver is synchronous *)
    Batch.trampoline (fun _ ->
      insert ~rows:current (fun res ->
        res
        |. Belt.Result.map (fun c -> c + count)
        |> next ~rows:rest
      )
    )
  (*
   * ## Run
   * Recursively run through the batch set of inserts
   *)
  let rec run ~batch_size ~driver ~insert ~resolver ~rows response =
    let next = run ~batch_size ~driver ~insert ~resolver
    in
    match response with
    | Belt.Result.Error error -> rollback ~error ~driver resolver
    | Belt.Result.Ok count ->
      match rows with
      | [||] -> count |. Belt.Result.Ok |. resolver
      | rows -> iterate ~count ~batch_size ~insert ~rows next
      |. ignore

  (*
   * `result` and `driver` types are an attempt to coerce the 
   * type system into the desired behavior
   *)
  type result = [ `Error of exn | `Mutation of Driver.Mutation.t]

  type driver =
    (
      sql: string ->
      (result -> unit) ->
      unit
    )
  (*
   * ## Start
   * Initiate the insert loop.
   *)
  let start ~driver:driver ?batch_size ~table ~columns ~rows callback =
    let batch_size = Batch.size batch_size in
    let insert ~rows next =
      execute ~driver ~sql:(Batch.Sql.insert table columns rows) next
    in
    let resolver res =
      match res with
      | Belt.Result.Error error -> rollback ~error ~driver callback
      | Belt.Result.Ok count -> commit ~count ~driver callback
    in
    execute ~driver ~sql:"START TRANSACTION" (fun res ->
      match res with
      | Belt.Result.Error error -> rollback ~error ~driver callback
      | Belt.Result.Ok _ ->
        run ~batch_size ~driver ~insert ~resolver ~rows (Belt.Result.Ok 0)
    )
    |. ignore
end
