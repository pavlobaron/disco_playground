#!/bin/sh

disco stop
make

~/opt/riak/rel/riak1/bin/riak stop
#~/opt/riak/rel/riak2/bin/riak stop
#~/opt/riak/rel/riak3/bin/riak stop

~/opt/riak/rel/riak1/bin/riak start
#~/opt/riak/rel/riak2/bin/riak start
#~/opt/riak/rel/riak3/bin/riak start

#~/opt/riak/rel/riak2/bin/riak-admin cluster join riak1@127.0.0.1
#~/opt/riak/rel/riak3/bin/riak-admin cluster join riak1@127.0.0.1
disco start
