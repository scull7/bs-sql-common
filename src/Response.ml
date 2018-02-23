type sql = string

type response =
  | Mutation of Result.Mutation.t
  | Select of Result.Select.t
  | Error of exn

module Promise = struct
  let selectOrError = function
    | Result.ResultMutation _ -> failwith "unexpected_mutation_result"
    | Result.ResultSelect s -> Js.Promise.resolve s

  module Select = struct
    let rows s = Js.Promise.(
      selectOrError s
      |> then_ (fun x -> x |> Result.Select.getRows |> resolve)
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
