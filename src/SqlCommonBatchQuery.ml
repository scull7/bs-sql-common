external sqlformat : string -> [`Positional of Js.Json.t] -> string = "format"
[@@bs.module "sqlstring"]

external array_to_params : 'a array -> [`Positional of Js.Json.t] = "%identity"
external params_to_array : [`Positional of Js.Json.t] -> 'a array = "%identity"
external to_array : 'a -> 'b array array = "%identity"
external to_params : 'a -> [`Positional of Js.Json.t] = "%identity"

external jsonIntMatrix : int array array -> Js.Json.t = "%identity"

type iteration = {
  params: [`Positional of Js.Json.t];
  data: Js.Json.t array;
  meta: MySql2.meta_record array;
}

let iteration ?prev params data meta  =
  match prev with
  | None -> { params; data; meta; }
  | Some(p) ->
    let data = Belt_Array.concat p.data data in
    let meta = Belt_Array.concat p.meta meta in
    { params; data; meta; }

    let db_call ~execute ~sql ?params ~fail ~ok _ =
  let _ = execute ~sql ?params (fun res ->
    match res with
    | `Error e -> fail e
    | `Select ((data:Js.Json.t array), (meta:MySql2.meta)) -> ok data meta
  )
  in ()

(* Takes the params from positional to 'a for sqlformat *)
let unwrap params =
  match params with
  | `Positional p -> p

let unwrap_p params =
  match params with
  | `Positional p -> `Positional p


let query_batch ~execute ~sql ~params ~fail ~ok _ =
  (* let _ = Js.log("params", params) in *)
  (* let  *)
  let sql_with_params = sqlformat sql params in
  (* let sql_with_params = sqlformat sql params in *)
  let _ = Js.log("in query_batch", sql_with_params) in
  db_call ~execute ~sql:sql_with_params ~fail ~ok ()

  let iterate ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
    let params_array = params_to_array (params) in
    let len = Belt_Array.length params_array in
    let elem = Belt_Array.get params_array 0 in
    let inner = match elem with
    | Some arr -> arr
    | None -> [||]
    in
    let _ = Js.log("inner", inner) in
    let real_batch = Belt_Array.slice inner ~offset:0 ~len:batch_size in
    let _ = Js.log("real_batch", real_batch) in
    let batch_as_params = array_to_params [|real_batch|] in
    let _ = Js.log("batch_as_params", batch_as_params) in
    let real_rest = Belt_Array.slice inner ~offset:batch_size ~len: len in
    let rest_as_array = array_to_params [|real_rest|] in
    let _ = Js.log("real rest", real_rest) in
    (* Here is where we need to adjust what we are slicing *)
    (* let batch = array_to_params (Belt_Array.slice params_array ~offset:0 ~len:batch_size) in *)
    (* let _ = Js.log("batch in iterate", batch) in *)
    let execute = (fun () -> query_batch_partial
      ~params:batch_as_params
      ~fail
      ~ok: (fun data meta -> ok (iteration ~prev rest_as_array data meta ))
      ()
    )
    in
    (* Trampoline, in case the connection driver is synchronous *)
    let _ = Js.Global.setTimeout execute 0 in ()

  (* let iterate ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
    let params_array = params_to_array (params) in
    let len = Belt_Array.length params_array in
    let real_batch = Belt_Array.slice params_array ~offset:0 ~len:batch_size in
    let batch_as_params = array_to_params [|real_batch|] in
    (* let params_array_array = to_array params_array in *)
    let real_rest = Belt_Array.slice params_array ~offset:batch_size ~len: len in
    let rest_as_array = array_to_params [|real_rest|] in
    (* let actual_params = Belt_Array.get elem 0 in *)
    (* let safe_actual_params =  *)
    (* let _ = Js.log("paa", params_array_array) in *)
    (* let real_rest = Belt_Array.slice b ~offset:batch_size ~len: len in
    let rest_as_array = array_to_params [|real_rest|] in *)
    let _ = Js.log("real rest", real_rest) in
    (* Here is where we need to adjust what we are slicing *)
    let batch = array_to_params (Belt_Array.slice params_array ~offset:0 ~len:batch_size) in
    let _ = Js.log("batch in iterate", batch) in
    (* let rest = array_to_params (Belt_Array.slice params_array ~offset:batch_size ~len:len) in *)
    let execute = (fun () -> query_batch_partial
      ~params:batch_as_params
      ~fail
      ~ok: (fun data meta -> ok (iteration ~prev rest_as_array data meta ))
      ()
    )
    in
    (* Trampoline, in case the connection driver is synchronous *)
    let _ = Js.Global.setTimeout execute 0 in () *)

(* let iterate ~query_batch_partial ~batch_size ~params ~fail ~ok ~prev _ =
  let params_array = params_to_array (params) in
  let len = Belt_Array.length params_array in
  let params_array_array = to_array params_array in
  (* This is probably magical and dangerous *)
  let elem = Belt_Array.get params_array_array 1 in
  let a = match elem with
  | Some arr -> arr
  | None -> [||]
  in
  let _ = Js.log("elem", a) in
  let single_param_list = Belt_Array.get a 0 in
  let b = match single_param_list with
  | Some arr -> arr
  | None -> [||]
  in
  let _ = Js.log("bbb", b) in
  let real_batch = Belt_Array.slice b ~offset:0 ~len:batch_size in
  let _ = Js.log("real batch", real_batch) in
  let pos = Some(`Positional (Json.Encode.array Json.Encode.int real_batch)) in
  let _ = Js.log("pos", pos) in
  let batch_as_array = array_to_params [|real_batch|] in
  (* let params_after_convers *)
  let _ = Js.log("batch_as_array", batch_as_array) in
  (* let actual_params = Belt_Array.get elem 0 in *)
  (* let safe_actual_params =  *)
  let _ = Js.log("paa", params_array_array) in
  let real_rest = Belt_Array.slice b ~offset:batch_size ~len: len in
  let rest_as_array = array_to_params [|real_rest|] in
  let _ = Js.log("real rest", real_rest) in
  (* Here is where we need to adjust what we are slicing *)
  let batch = array_to_params (Belt_Array.slice params_array ~offset:0 ~len:batch_size) in
  let _ = Js.log("batch in iterate", batch) in
  let rest = array_to_params (Belt_Array.slice params_array ~offset:batch_size ~len:len) in
  let execute = (fun () -> query_batch_partial
    ~params:batch_as_array
    ~fail
    ~ok: (fun data meta -> ok (iteration ~prev rest_as_array data meta ))
    ()
  )
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout execute 0 in () *)

let rec run ~batch_size ~iterator ~fail ~ok iteration =
  let run_without_iteration = run ~batch_size ~iterator ~fail ~ok in
  let { params; data; meta } = iteration in
  let params_array = params_to_array (params) in
  let elem = Belt_Array.get params_array 0 in
  let inner = match elem with
  | Some arr -> arr
  | None -> [||]
  in
  match Belt_Array.length inner with
  | 0 -> ok data meta
  | _ -> iterator ~batch_size ~params ~fail ~ok:run_without_iteration ~prev:iteration ()

let valid_query_params params =
  let array_params = to_array (unwrap params) in
  let _ = Js.log array_params in
  match (Belt_Array.length array_params) with
  | 1 -> true
  | _ -> false

let query execute ?batch_size ~sql ~params user_cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  (* let _ = Js.log("unwrapped params", (unwrap params)) in *)
  let p = unwrap params in
  let params_again = to_params p in
  let _ = Js.log("params again", params_again) in
  let fail = (fun e -> user_cb (`Error e)) in
  let complete = (fun data meta ->
    user_cb(`Select(data, meta))
  ) in
  let query_batch_partial = query_batch ~execute ~sql in
  let iterator = iterate ~query_batch_partial in
  run
    ~batch_size
    ~iterator
    ~fail
    ~ok:complete
    (iteration params_again [||] [||])
