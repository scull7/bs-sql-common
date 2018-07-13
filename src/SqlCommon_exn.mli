exception InvalidQuery of string

exception InvalidResponse of string

module Invalid : sig
  module Query : sig
    exception IllegalUseOfIn of string

    val illegal_use_of_in : exn
  end

  module Response : sig
    exception ExpectedSelect of string

    exception ExpectedMutation of string

    val expected_mutation : exn

    val expected_select : exn

    val expected_select_no_response : exn
  end
end
