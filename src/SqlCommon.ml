
module Exn = SqlCommon_exn

module type Queryable = SqlCommon_queryable.Queryable

module Make(Driver: Queryable) = struct

  module Connection = Driver.Connection

  module Callback = SqlCommon_callback.Make(Driver)

  module Promise = SqlCommon_callback.Make(Driver)

  module Batch = struct
    module Mutate = struct
      module Internal = SqlCommon_batch_insert.Make(Driver)

      let start db ?batch_size table columns rows callback =
        Internal.start
          ~driver:(Callback.Mutate.run db ?params:None)
          ?batch_size
          ~table
          ~columns
          ~rows
          callback
    end

    module Query = SqlCommon_batch_query.Make(Driver)
  end

end
