-module(erl_inputs).

-export([transform/1, test/1]).

-spec transform(string()) -> string().
transform(Input) ->
    try
        <<"erl://", MFB/binary>> = Input,
      MF = binary_to_list(MFB),
      P1 = string:str(MF, ":"),
      P2 = string:str(MF, "/"),
      Module = string:sub_string(MF, 1, P1 - 1),
      Function = string:sub_string(MF, P1 + 1, P2 - 1),
      Parameter = string:sub_string(MF, P2 + 1),
      list_to_binary(apply(list_to_atom(Module), list_to_atom(Function), [Parameter]))
    catch _:_ ->
        Input
    end.

-spec test(string()) -> string().
test(Parameter) ->
    "raw://dummy test " ++ Parameter.
