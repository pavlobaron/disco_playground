from disco.core import Job, result_iterator

def map(line, params):
    for word in line.split():
        yield word, 1

def reduce(iter, params):
    from disco.util import kvgroup
    for word, counts in kvgroup(sorted(iter)):
        yield word, sum(counts)

if __name__ == '__main__':
    job = Job().run(input=["erl://riak_stream:local_vnodes_stream/twitterbk"],
                    map=map,
                    reduce=reduce,
                    required_modules=[('rabbitio', '/Users/pb/code/rabbitio'),
                                      ('pika', '/Users/pb/code/pika')])
    for word, count in result_iterator(job.wait(show=True)):
        print word, count
