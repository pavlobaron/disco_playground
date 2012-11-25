-module(riak_stream).

-export([local_vnodes_stream/1,
         receiver_loop/4,
         sender_loop/4]).

-record(queue, {name,
                url,
                connection,
                channel).

-include("amqp_client.hrl").

-spec local_vnodes_stream(string()) -> string().
local_vnodes_stream(Bucket) ->
    VNodes = riak_core_vnode_manager:all_vnodes(),
    Preflist = [{X, Y} || {_, X, Y} <- VNodes],
    BBucket = list_to_binary(Bucket),
    Queue = create_queue(Bucket),
    spawn(?MODULE, receiver_loop, [self(), length(Preflist), BBucket, [], Queue]),
    spawn_senders(Preflist, length(Preflist), Receiver, BBucket),
    %% TODO: more than one receiver, probably one per vnode
    Queue#queue.url.


%% internals

create_queue(Bucket) ->
    QueueName = "riak_" ++ Bucket ++ "_" ++ atom_to_list(node()),
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'queue.declare_ok'{queue=QueueName} = amqp_channel:call(Channel, #'queue.declare'{}),
    Url = "queue://" ++ QueueName,
    #queue{name=QueueName, url=Url, connection=Connection, channel=Channel}.

publish(Queue, Data) ->
    Publish = #'basic.publish'{exchange=<<>>, routing_key = Queue#queue.name},
    amqp_channel:cast(Queue#queue.channel, Publish, #amqp_msg{payload=Data}),

-spec receiver_loop(pid(), integer(), binary(), term()) -> ok.
receiver_loop(Owner, 0, Bucket, VNodeKeys, Queue) ->
    Max = 4,%length(VNodeKeys),
    read_data(VNodeKeys, Max, Bucket, Queue);
receiver_loop(Owner, Count, Bucket, VNodeKeys, Queue) ->
    receive
        {_, []} ->
            receiver_loop(Owner, Count - 1, Bucket, VNodeKeys, Queue);
        {VNode, [{_, {_, _, Keys}}]} ->
            receiver_loop(Owner, Count - 1, Bucket,
                          [{VNode, lists:flatten(Keys)}|VNodeKeys], Queue)
    end.

read_data(_, 0, _, _) ->
    ok;
read_data([{VNode, Keys}|T], RefId, Bucket, Queue) ->
    BucketKeys = [{Bucket, Key} || Key <- Keys],
    ok = riak_kv_vnode:mget(VNode, BucketKeys, RefId),
    Max = 16,%length(Keys),
    Data = read_data_loop(Data, Max), %TODO: refactor to async, backpressure possible
    publish(Queue, Data)
    read_data(T, RefId - 1, Bucket, Queue).

read_data_loop(Data, 0) ->
    Data;
read_data_loop(Data, Counter) ->
    receive
        {_, {_, {r_object, _, _, [{r_content, _, Object}], _, _, _}, _, _}} ->
            %TODO: refactor to add a dummy vector clock, use riakc (but siblings?..)
            read_data_loop([Object, "\n"|Data], Counter - 1);
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
