module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct
  module Callback = SqlCommon_callback.Make(Driver)

  let close = Driver.Connection.close
  let connect = Driver.Connection.connect

  module Select = struct
    let run db ?params ~sql =
      Js.Promise.make (fun ~resolve ~reject ->
        Callback.Select.query db ?params ~sql (fun res ->
          match res with
          | Belt.Result.Error exn -> reject exn [@bs]
          | Belt.Result.Ok select -> resolve select [@bs]
        )
      )
  end

  module Mutate = struct
    let run db ?params ~sql =
      Js.Promise.make (fun ~resolve ~reject ->
        Callback.Mutate.run db ?params ~sql (fun res ->
          match res with
          | Belt.Result.Error exn -> reject exn [@bs]
          | Belt.Result.Ok mutation -> resolve mutation [@bs]
        )
      )
  end
end
