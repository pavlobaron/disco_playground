-module(riak_stream).

-export([local_vnodes_stream/1,
         receiver_loop/4,
         sender_loop/4]).

-spec local_vnodes_stream(string()) -> string().
local_vnodes_stream(Bucket) ->
    VNodes = riak_core_vnode_manager:all_vnodes(),
    Preflist = [{X, Y} || {_, X, Y} <- VNodes],
    BBucket = list_to_binary(Bucket),
    Receiver = spawn(?MODULE, receiver_loop, [self(), length(Preflist), BBucket, []]),
    spawn_senders(Preflist, length(Preflist), Receiver, BBucket),
    receive
        {data, Data} ->
            error_logger:info_msg("DATA: ~p   ~p~n", [length(Data), Data]),
            Data
    end.

%% internals

-spec receiver_loop(pid(), integer(), binary(), term()) -> ok.
receiver_loop(Owner, 0, Bucket, VNodeKeys) ->
    Max = 4,%length(VNodeKeys),
    %TODO: here, the huge memory usage hits hard:
    %hard limit here for live demo, but more for the mapper to get done at all
    %long_gc info messages flying around, too much heap on one single process.
    %+hms doesn't help, one single process flooded by data,
    %need to refactor the streaming to binaries and process them in Python,
    %plus stream in chunks. See README.md for more details on this issue
    Data = read_data(VNodeKeys, Max, Bucket, []),
    Owner ! {data, Data};
receiver_loop(Owner, Count, Bucket, VNodeKeys) ->
    receive
        {_, []} ->
            receiver_loop(Owner, Count - 1, Bucket, VNodeKeys);
        {VNode, [{_, {_, _, Keys}}]} ->
            receiver_loop(Owner, Count - 1, Bucket, [{VNode, lists:flatten(Keys)}|VNodeKeys])
    end.

read_data(_, 0, _, Data) ->
    Data;
read_data([{VNode, Keys}|T], RefId, Bucket, Data) ->
    BucketKeys = [{Bucket, Key} || Key <- Keys],
    ok = riak_kv_vnode:mget(VNode, BucketKeys, RefId),
    %TODO: see limitation comment above
    Max = 16,%length(Keys),
    Part = read_data_loop(Data, Max), %TODO: refactor to async, backpressure possible
    read_data(T, RefId - 1, Bucket, [Part|Data]).

read_data_loop(Data, 0) ->
    Data;
read_data_loop(Data, Counter) ->
    receive
        {_, {_, {r_object, _, _, [{r_content, _, Object}], _, _, _}, _, _}} ->
            %TODO: refactor to add a dummy vector clock, use riakc (but siblings?..)
            read_data_loop([binary_to_list(Object), "\n"|Data], Counter - 1);
        Dunno ->
            error_logger:error_msg("what is this? ~p~n", [Dunno]),
            read_data_loop(Data, Counter - 1)
    after
        500 ->
            read_data_loop(Data, Counter - 1)
    end.

spawn_senders(_, 0, _, _) ->
    ok;
spawn_senders([VNode|T], RefId, Receiver, Bucket) ->
    spawn(?MODULE, sender_loop, [VNode, RefId, Receiver, Bucket]),
    spawn_senders(T, RefId - 1, Receiver, Bucket).

-spec sender_loop(tuple(), integer(), pid(), binary()) -> ok.
sender_loop(VNode, RefId, Receiver, Bucket) ->
    riak_kv_vnode:list_keys([VNode], RefId, self(), Bucket),
    Part = keys_from_vnode([]),
    Receiver ! {VNode, Part}.

keys_from_vnode(Parts) ->
    receive
        {_, _, done} -> Parts;
        Part -> keys_from_vnode([Part|Parts])
    after
        100 -> Parts
    end.
