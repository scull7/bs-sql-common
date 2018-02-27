type sql = string

type mutation = SqlCommonResult.Mutation.t
type select = SqlCommonResult.Select.t

type response =
  | Mutation of mutation
  | Select of select
  | Error of exn

module Promise = struct
  module Result = struct
    type t =
      | Mutation of mutation
      | Select of select
  end
  let handler resolve reject resp =
    match resp with
    | Error e -> reject e [@bs]
    | Mutation m -> resolve (Result.Mutation m) [@bs]
    | Select s -> resolve (Result.Select s) [@bs]

  let selectOrError = function
    | Result.Mutation _ -> failwith "unexpected_mutation_result"
    | Result.Select s -> Js.Promise.resolve s

  module Select = struct
    let rows s = Js.Promise.(
      selectOrError s
      |> then_ (fun x -> x |> SqlCommonResult.Select.getRows |> resolve)
    )

    let decode decoder s = Js.Promise.(
      (rows s) |> then_ (fun x ->
        x
        |> Js.Array.map @@ decoder
        |> resolve
      )
    )

    let decodeOne decoder s = Js.Promise.(
      (rows s) |> then_ (fun x ->
        (match x with
        | [||] -> None
        | [|y|] -> Some (decoder y)
        | _ -> failwith "invalid_response_more_than_one")
        |> resolve
      )
    )
  end
end
