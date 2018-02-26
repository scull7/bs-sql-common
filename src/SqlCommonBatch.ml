
module Response = SqlCommonResponse

external sqlformat : string -> 'a Js.Array.t -> string = "format"
[@@bs.module "sqlstring"]

let raw = SqlCommonWrapper.query

type 'a iteration =
  | Iterate of 'a array * Response.mutation
  | Error of Response.response

let empty_mutation: Response.mutation = {
  affected_rows = 0;
  insert_id = None;
  info = Some("SQLCOMMON_BATCH_INSERT");
  server_status = None;
  warning_status = 0;
  changed_rows = 0;
}

let unexpected_select = Response.Error (Failure "unexpected_select_result")

let update_mutation (prev : Response.mutation) (current : Response.mutation): Response.mutation =
  let affected_rows = prev.affected_rows + current.affected_rows in
  let changed_rows = prev.changed_rows + current.changed_rows
  in
  { current with
    affected_rows = affected_rows;
    changed_rows =  changed_rows;
    info = prev.info;
  }

let rollback conn cb res =
  raw conn "ROLLBACK" (fun resp ->
    match resp with
    | Response.Error e -> cb (Response.Error e)
    | Response.Select _ -> failwith "rollback :: Unexpected Select Response"
    | Response.Mutation _ -> cb res
  )

let rollback_on_error conn cb res =
  let r = rollback conn cb in
  match res with
  | Response.Error e -> r (Response.Error e)
  | Response.Select _ -> r unexpected_select
  | Response.Mutation _ -> cb res

let commit conn cb res =
  raw conn "COMMIT" (rollback_on_error conn (fun _ -> cb res))

let finished conn cb res =
  rollback_on_error conn (commit conn cb) res

let iterate batch_size fn rows last next =
  let len = Belt_Array.length rows in
  let batch = Belt_Array.slice rows ~offset:0 ~len:batch_size in
  let rest = Belt_Array.slice rows ~offset:batch_size ~len:len
  in
  (* Trampoline, in case the connection driver is synchronous *)
  let _ = Js.Global.setTimeout (fun () ->
    fn batch (fun resp ->
      let result = match resp with
      | Response.Error e -> Error (Response.Error e)
      | Response.Select _ -> Error unexpected_select
      | Response.Mutation m -> Iterate (rest, (last m))
      in
      next result
    )
  ) 0
  in ()

let rec run batch_size fn finished iteration =
  let next = run batch_size fn finished in
  match iteration with
  | Error err -> finished err
  | Iterate (rows, prev) ->
    match rows with
    | [||] -> finished (Response.Mutation prev)
    | r -> iterate batch_size fn r (update_mutation prev) next

let insert_batch conn table columns rows cb =
  let sql_tmpl = {j|INSERT INTO $table (??) VALUES ?|j} in
  let params = [|columns; rows|] in
  (*
    Have to use this because MySQL2 doesn't properly
    handle the table name escaping
   *)
  let sql = sqlformat sql_tmpl params in
  SqlCommonWrapper.execute conn sql (`ParamsUnnamed (Js.Nullable.return params)) cb

let insert conn ?batch_size ~table ~columns ~rows cb =
  let batch_size =
    match batch_size with
    | None -> 1000
    | Some(s) -> s
  in
  let fn = insert_batch conn table columns in
  let finished = finished conn cb
  in
  raw conn "START TRANSACTION" (fun resp ->
    match resp with
    | Response.Error e -> cb (Response.Error e)
    | _ -> run batch_size fn finished (Iterate (rows, empty_mutation))
  )
