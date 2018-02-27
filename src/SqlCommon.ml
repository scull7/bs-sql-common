module Error = SqlCommonError
module Response = SqlCommonResponse

let raw = SqlCommonWrapper.query

let with_params conn sql params cb =
  SqlCommonWrapper.execute conn sql (`ParamsUnnamed (Js.Nullable.return params)) cb

let with_named_params conn sql params cb =
  SqlCommonWrapper.execute conn sql (`ParamsNamed (Js.Nullable.return params)) cb

let batch_insert conn ?batch_size ~table ~columns ~rows cb =
  SqlCommonBatch.insert conn ?batch_size ~table ~columns ~rows cb

module Promise = struct
  let handler = Response.Promise.handler

  let raw conn sql =
    Js.Promise.make (fun ~resolve ~reject ->
      raw conn sql (handler resolve reject))

  let batch_insert conn batch_size table columns rows =
    Js.Promise.make (fun ~resolve ~reject ->
      batch_insert conn ?batch_size ~table ~columns ~rows (handler resolve reject))

  let with_params conn sql params =
    Js.Promise.make (fun ~resolve ~reject ->
      with_params conn sql params (handler resolve reject))

  let with_named_params conn sql params =
    Js.Promise.make (fun ~resolve ~reject ->
      with_named_params conn sql params (handler resolve reject))

  let pipe_with_params sql params pconn =
    pconn |> Js.Promise.then_ (fun conn -> with_params conn sql params)

  let pipe_with_named_params sql params pconn =
    pconn |> Js.Promise.then_ (fun conn -> with_named_params conn sql params)
end
