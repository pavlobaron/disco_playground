-module(erl_inputs).

-export([transform/1, test/0]).

-spec transform(string()) -> string().
transform(Input) ->
    try
        <<"erl://", MFB/binary>> = Input,
      MF = binary_to_list(MFB),
      P1 = string:str(MF, ":"),
      P2 = string:str(MF, "/"),
      M = string:sub_string(MF, 1, P1 - 1),
      F = string:sub_string(MF, P1 + 1, P2 - 1),
      list_to_binary("raw://" ++ apply(list_to_atom(M), list_to_atom(F), []))
    catch _:_ ->
        Input
    end.

-spec test() -> string().
test() ->
    "this is just a test".
