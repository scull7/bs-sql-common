exception InvalidQuery of string

exception InvalidResponse of string

let message subtype code number msg =
  {j|SqlCommonError - $subtype ($number) - $code: $msg|j}

module Invalid = struct

  let message subtype code msg = message subtype code "99999" msg

  module Param = struct
    let message code msg = message "InvalidParam" code msg

    exception UnsupportedParamType of string

    let unsupported_param_type expected_type = UnsupportedParamType(
      message
      "UNSUPPORTED_PARAM_TYPE"
      (
        String.concat
        " - "
        [
          "Used an unsupported type of JSON in your parameters expected ";
          expected_type;
        ]
      )
    )
  end

  module Query = struct
    let message code msg = message "InvalidQuery" code msg

    exception IllegalUseOfIn of string

    exception IllegalUseOfMultipleParams of string

    let illegal_use_of_in = IllegalUseOfIn(
      message
      "ILLEGAL_USE_OF_IN"
      (
        String.concat
        " - "
        [
        "Do not use 'IN' with non-batched operations";
        "use a batch operation instead";
        ]
      )
    )

    let illegal_use_of_multiple_params = IllegalUseOfMultipleParams(
      message
      "ILLEGAL_USE_OF_MULTIPLE_PARAMS"
      (
        String.concat
        " - "
        [
        "Do not use query_batch for queries with multiple parameters -";
        "use a non-batched operation instead";
        ]
      )
    )
  end

  module Response = struct
    let message code msg = message "InvalidResponse" code msg

    exception ExpectedSelect of string

    exception ExpectedMutation of string

    let expected_mutation = ExpectedMutation(
      message
      "EXPECTED_MUTATION"
      "Expected a mutation response but received a select response"
    )

    let expected_select = ExpectedSelect(
      message
      "EXPECTED_SELECT"
      "Expected a select response but received a mutation response"
    )

    let expected_select_no_response = ExpectedSelect(
      message
      "EXPECTED_SELECT"
      "Expected a select response but received a nil response"
    )
  end
end
