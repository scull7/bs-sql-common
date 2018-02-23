type sql = string

type response =
  | Mutation of SqlCommonResult.Mutation.t
  | Select of SqlCommonResult.Select.t
  | Error of exn

module Promise = struct
  let selectOrError = function
    | SqlCommonResult.ResultMutation _ -> failwith "unexpected_mutation_result"
    | SqlCommonResult.ResultSelect s -> Js.Promise.resolve s

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
