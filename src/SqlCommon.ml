
module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct
  module Callback = SqlCommon_callback.Make(Driver)
  module BatchMutate = SqlCommon_batch_insert.Make(Driver)
  module BatchQuery = SqlCommon_batch_query.Make(Driver)

  module Connection = Driver.Connection

  module Pool = SqlCommon_pool.Make(Driver)

  module Id = struct
    type t = Driver.Id.t

    let fromJson = Driver.Id.fromJson

    let toJson = Driver.Id.toJson

    let toString = Driver.Id.toString
  end

  module Params = struct
    type t = Driver.Params.t

    let named = Driver.Params.named

    let positional = Driver.Params.positional
  end

  module Response = struct
    module Mutation = struct
      type t = Driver.Mutation.t

      let insertId = Driver.Mutation.insertId

      let affectedRows = Driver.Mutation.affectedRows
    end

    module Select = struct
      type t = Driver.Select.t

      module Meta = struct
        type t = Driver.Select.Meta.t

        let schema = Driver.Select.Meta.schema

        let name = Driver.Select.Meta.name

        let table = Driver.Select.Meta.table
      end

      let meta = Driver.Select.meta

      let concat = Driver.Select.concat

      let count = Driver.Select.count

      let flatMap = Driver.Select.flatMap

      let flatMapWithMeta = Driver.Select.flatMapWithMeta

      let rows = Driver.Select.rows

    end
  end

  let mutate ~db ~sql ?params callback =
    Callback.Mutate.run db ~sql ?params callback

  let query ~db ~sql ?params callback =
    Callback.Select.query db ~sql ?params callback

  module Batch = struct

    let mutate ~db ?batch_size ~table ~columns ~encoder ~rows callback =
      BatchMutate.start
        ~driver:(Callback.Mutate.run db ?params:None)
        ?batch_size
        ~table
        ~columns
        ~encoder
        ~rows
        callback


    let query ~db ?batch_size ~sql ~params callback =
      BatchQuery.start
        ~driver:(Callback.Select.query db ?params:None)
        ?batch_size
        ~sql
        ~params
        callback
  end

  module Promise = struct
    module Internal = SqlCommon_promise.Make(Driver)

    let mutate ~db ?params ~sql = Internal.Mutate.run db ?params ~sql 

    let query ~db ?params ~sql = Internal.Select.run db ?params ~sql

    module Batch = struct
      let mutate ~db ?batch_size ~table ~columns ~encoder ~rows _ =
        Js.Promise.make (fun ~resolve ~reject ->
          BatchMutate.start
            ~driver:(Callback.Mutate.run db ?params:None)
            ?batch_size
            ~table
            ~columns
            ~encoder
            ~rows
            (fun res ->
              match res with
              | Belt.Result.Error exn -> reject exn [@bs]
              | Belt.Result.Ok mutation -> resolve mutation [@bs]
            )
        )

      let query ~db ?batch_size ~sql ~params _ =
        Js.Promise.make (fun ~resolve ~reject ->
          BatchQuery.start
            ~driver:(Callback.Select.query db ?params:None)
            ?batch_size
            ~sql
            ~params
            (fun res ->
              match res with
              | Belt.Result.Error exn -> reject exn [@bs]
              | Belt.Result.Ok select -> resolve select [@bs]
            )
        )
    end
  end

end
