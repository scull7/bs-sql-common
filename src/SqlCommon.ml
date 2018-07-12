
module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct

  module Connection = Driver.Connection

  module Callback = SqlCommon_callback.Make(Driver)

  module Promise = SqlCommon_callback.Make(Driver)

  module Id = struct
    type t = Driver.Id.t

    let fromJson = Driver.Id.fromJson

    let toJson = Driver.Id.toJson

    let toString = Driver.Id.toString
  end

  module Response = struct
    module Mutation = struct
      let insertId = Driver.Mutation.insertId

      let affectedRows = Driver.Mutation.affectedRows
    end

    module Select = Driver.Select
  end

  let mutate = Callback.Mutate.run

  let query = Callback.Select.query

  module Batch = struct
    module Mutate = struct
      module Internal = SqlCommon_batch_insert.Make(Driver)

      let start ~db ?batch_size ~table ~columns ~rows callback =
        Internal.start
          ~driver:(Callback.Mutate.run db ?params:None)
          ?batch_size
          ~table
          ~columns
          ~rows
          callback
    end

    module Query = struct
      module Internal = SqlCommon_batch_query.Make(Driver)

      let start ~db ?batch_size ~sql ~params callback =
        Internal.start
          ~driver:(Callback.Select.query db ?params:None)
          ?batch_size
          ~sql
          ~params
          callback
    end

  end

end
