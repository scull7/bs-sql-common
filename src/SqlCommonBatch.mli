val insert :
  'a ->
  ?batch_size:int ->
  table:string ->
  columns:'b array ->
  rows: 'b array ->
  (SqlCommonResponse.response -> unit) ->
  unit
