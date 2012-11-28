-module(riak_stream).

-export([local_vnodes_stream/1,
         receiver_loop/4,
         sender_loop/4]).

-record(queue, {name,
                url,
                connection,
                channel}).

-include("amqp_client.hrl").

-spec local_vnodes_stream(string()) -> string().
local_vnodes_stream(Bucket) ->
    VNodes = riak_core_vnode_manager:all_vnodes(),
    Preflist = [{X, Y} || {_, X, Y} <- VNodes],
    BBucket = list_to_binary(Bucket),
    Queue = create_queue(Bucket),    
    Receiver = spawn(?MODULE, receiver_loop, [length(Preflist), BBucket, [], Queue]),
    spawn_senders(Preflist, length(Preflist), Receiver, BBucket),
    %% TODO: more than one receiver, probably one per vnode
    Queue#queue.url.


%% internals

create_queue(Bucket) ->
    SQueueName = "riak_" ++ Bucket ++ "_" ++ atom_to_list(node()),
    QueueName = list_to_binary(SQueueName),
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'queue.declare_ok'{queue=QueueName} = amqp_channel:call(Channel,
                                                 #'queue.declare'{queue = QueueName,
                                                                 durable = true,
                                                                 exclusive = false,
                                                                 auto_delete = false}),
    Url = "queue://" ++ SQueueName,
    #queue{name=QueueName, url=Url, connection=Connection, channel=Channel}.

publish(Queue, Data) ->
    Publish = #'basic.publish'{exchange = <<"">>, routing_key = Queue#queue.name},
    amqp_channel:cast(Queue#queue.channel, Publish, #amqp_msg{payload = Data}).

-spec receiver_loop(integer(), binary(), term(), record()) -> ok.
receiver_loop(0, Bucket, VNodeKeys, Queue) ->
    Max = length(VNodeKeys),
    read_data(VNodeKeys, Max, Bucket, Queue);
receiver_loop(Count, Bucket, VNodeKeys, Queue) ->
    receive
        {_, []} ->
            receiver_loop(Count - 1, Bucket, VNodeKeys, Queue);
        {VNode, [{_, {_, _, Keys}}]} ->
            receiver_loop(Count - 1, Bucket,
                          [{VNode, lists:flatten(Keys)}|VNodeKeys], Queue)
    end.

read_data(_, 0, _, _) ->
    ok;
read_data([{VNode, Keys}|T], RefId, Bucket, Queue) ->
    BucketKeys = [{Bucket, Key} || Key <- Keys],
    ok = riak_kv_vnode:mget(VNode, BucketKeys, RefId),
    Max = length(Keys),
    read_data_loop(Max, Queue), %TODO: refactor to async, backpressure possible
    read_data(T, RefId - 1, Bucket, Queue).

read_data_loop(0, _) ->
    ok;
read_data_loop(Counter, Queue) ->
    receive
        {_, {_, {r_object, _, _, [{r_content, _, Object}], _, _, _}, _, _}} ->
            %TODO: refactor to add a dummy vector clock, use riakc (but siblings?..)
            publish(Queue, Object),
            read_data_loop(Counter - 1, Queue);
        Dunno ->
            error_logger:error_msg("what is this? ~p~n", [Dunno]),
            read_data_loop(Counter - 1, Queue)
    after
        500 ->
            read_data_loop(Counter - 1, Queue)
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
