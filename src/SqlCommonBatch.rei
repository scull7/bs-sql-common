let insert: (
  (
    ~sql: string,
    ~params: 'a=?,
    [<
    | `Error(exn)
    | `Mutation(int, int)
    ] => unit
  ) => unit,
  ~batch_size: int=?,
  ~table: string,
  ~columns: array('b),
  ~rows: array('b),
  [>
  | `Error(exn)
  | `Mutation(int, int)
  ] => unit
) => unit;
