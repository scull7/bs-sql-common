module Batch = SqlCommon_batch
module Exn = SqlCommon_exn
module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct
  module Params = Driver.Params

  module Tracker = struct
    type t = {
      batch_size: int;
      params: Js.Json.t array;
      cursor: int;
      response: Driver.Select.t option;
    }

    let make batch_size params =
      { batch_size; params; cursor = 0; response = None }

    let concatSelect t select =
      { t with response =
          match t.response with
          | None -> Some select
          | Some s -> Some (Driver.Select.concat s select)
      }

    let next t = { t with cursor = t.cursor + t.batch_size }

    let response t = t.response

    let current t =
      Belt.Array.slice t.params ~offset:t.cursor ~len:t.batch_size

    let hasMore t = t.cursor < (Belt.Array.length t.params) - 1
  end

  let execute ~driver ~sql ~params resolver =
    driver ~sql:(SqlCommon_sql.format sql params) resolver |. ignore

  (*
   * ## Iterate
   * Handle a single iteration.  This function automatically bounces
   * out of synchronous execution in case we have a driver which is
   * inherently synchronous.
   *)
  let iterate ~driver ~sql ~tracker next =
    let current = Tracker.current tracker in
    let tracker = Tracker.next tracker
    in
    Batch.trampoline (fun _ ->
      execute ~driver ~sql ~params:current (fun res ->
        Belt.Result.map res (fun s -> Tracker.concatSelect tracker s)
        |. next
      )
    )
    |. ignore

  (*
   * ## Run
   * Recursively run through the batch set of parameters
   *)
  let rec run ~driver ~sql ~resolver response =
    let next = run ~driver ~sql ~resolver
    in
    match response with
    | Belt.Result.Error _ -> response |. resolver
    | Belt.Result.Ok tracker ->
        match (tracker |. Tracker.hasMore) with
        | false -> response |. resolver
        | true -> iterate ~driver ~sql ~tracker next
  (*
   * ## Start
   * Initiate the query loop
   *)
    let start ~driver ?batch_size ~sql ~params:(`Positional json) callback =
      let batch_size = Batch.size batch_size in
      let tracker = Belt.Result.Ok (Tracker.make batch_size json) in
      let no_response = Exn.Invalid.Response.expected_select_no_response in
      let resolver = (fun res ->
        res
        |. Belt.Result.map Tracker.response
        |. Belt.Result.flatMap (fun res ->
            match res with
            | None -> no_response |. Belt.Result.Error
            | Some res -> res |. Belt.Result.Ok
        )
        |. callback
      )
      in
      run ~driver ~sql ~resolver tracker |. ignore


end
