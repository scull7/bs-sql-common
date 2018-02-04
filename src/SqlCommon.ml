module Error = Error
module Response = Response

let raw = Wrapper.query

let with_params conn sql params cb =
  Wrapper.execute conn sql (`ParamsUnnamed (Js.Nullable.return params)) cb

let with_named_params conn sql params cb =
  Wrapper.execute conn sql (`ParamsNamed (Js.Nullable.return params)) cb

module Promise = struct
  let handler resolve reject response =
    match response with
    | Response.Error e -> reject e [@bs]
    | any -> resolve any [@bs]

  let raw conn sql =
    Js.Promise.make (fun ~resolve ~reject ->
      raw conn sql (handler resolve reject))

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
