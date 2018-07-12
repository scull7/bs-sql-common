module Batch = SqlCommon_batch
module Exn = SqlCommon_exn
module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct
  module Params = Driver.Params
  module Select = Driver.Select

  module Tracker = struct
    type t = {
      batch_size: int;
      params: Js.Json.t array;
      cursor: int;
      response: Select.t option;
    }

    let make batch_size json =
      match (json |. Js.Json.classify) with
      | Js.Json.JSONArray params ->
          { batch_size; params; cursor = 0; response = None } |. Belt.Result.Ok
      | _ ->
          "Array"
          |. Exn.Invalid.Param.unsupported_param_type
          |. Belt.Result.Error

    let concatSelect t select =
      { t with response =
          match t.response with
          | None -> Some select
          | Some s -> Some (Select.concat s select)
      }

    let next t = { t with cursor = t.cursor + t.batch_size }

    let response t = t.response

    let current t =
      Belt.Array.slice t.params ~offset:t.cursor ~len:t.batch_size

    let hasMore t = t.cursor < (Belt.Array.length t.params) - 1
  end

  let execute ~driver ~sql ~params resolver =
     let sql = SqlCommon_sql.format sql params
     in
     driver ~sql (fun res ->
      match res with
      | `Error e -> e |. Belt.Result.Error |. resolver
      | `Select s -> s |. Belt.Result.Ok |. resolver
    )
    |. ignore

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
        match res with
        | Belt.Result.Error error -> error |. Belt.Result.Error |. next
        | Belt.Result.Ok select ->
            tracker
            |. Tracker.concatSelect select
            |. Belt.Result.Ok
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
      let tracker = Tracker.make batch_size json in
      let resolver = (fun res ->
        match res with
        | Belt.Result.Error error -> (`Error error) |. callback
        | Belt.Result.Ok tracker ->
            tracker
            |. Tracker.response
            |. (fun t ->
                match t with
                | None -> `Error Exn.Invalid.Response.expected_select_no_response
                | Some t -> `Select t
            )
            |. callback
      )
      in
      run ~driver ~sql ~resolver tracker |. ignore


end
