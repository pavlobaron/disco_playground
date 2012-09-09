## How read inputs from local Riak vnodes ##

The main principle is data locality. So Riak isn't being talked to through one of its general high level interfaces, but rather through a low level Erlang interface on a local node. Riak and Disco nodes are all the same in this case, and Disco connects to already running nodes rather to start new slaves - per configuration, of course.

### Why would I need this? ###

Well, there are different reasons. First of all, Disco's ddfs is good for storing big pieces of data, possibly being chunked. If you have many small data pieces, you would have to combine them to something bigger, which is not always comfortable. Further, if you already have a running Riak cluster (maybe a shadow of production), you wouldn't want to run into the split phase moving data from Riak to Disco before analysing it. Further, Riak offers some ways to do MapReduce, but if you want to do it in-place, you would either have to go for Erlang or JavaScript. And Python is still the very king of scientific solutions, so for serious ML, NLP and similar stuff you would have to trick. Of course, it's possible to do embedded Python in a running Erlang node, but where is the fun? Disco offers a real nice and easy-to-use Python way to write your jobs, so you have a comfortable way to do this.

### Status ###

Right now, it's a first step working for a own very special use case. It only has one writer and it always just adds new records. So, concurrent writes with version conflicts are out of consideration. In this case, you can ask a Riak node locally for its vnodes and pull the data out of them. What is seriously needed is to consider how one can avoid several physical nodes running jobs on the same data since on key gets replicated. Maybe some sort of ranges or such. It's now building on the reducer to get rid of duplicates, but in case of real huge data amounts and a need to be fast on analytics withouth overhead, a solution for this issue is needed. You could overcome this issue by configuring only one node per replica set to be connected by Disco. But when this node fails, you either exclude a percentage of data from analytics, or Disco would have to be extended to be able to accept whole replica sets per slave to have alternative entry points.

What also might be interesting is auto-discovery of nodes, either through Riak or by the means of distributed Erlang. One concern could be that it breaks the explicit node configuration you do in Disco to name the slaves to run jobs on. But you win more in a distributed system such as Riak.

There is also the blacklist feature in Disco which could probably be used for this.

