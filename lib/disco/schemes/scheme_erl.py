def input_stream(fd, sze, url, params):
    """Opens a StringIO whose data is everything after the url scheme,
    which is an Erlang function call like 'module:fun/0'. No arguments
    are accepted (yet), thus the function needs to autonomously get its data
    from somewhere, for example from the local Riak data node (see examples).

    Further, it's obvious that currently the called function can only be
    synchronous, thus returning all results on return.

    The same function will be called on every available node, so the
    corresponding module needs to be on the path.

    Internally, erl.// is being transformed into raw://, containing
    the result of the called Erlang function. There possibly is a flaw
    in this method since results can be very many, so raw:// can flood
    memory. Further tests are necessary.
    """
    from cStringIO import StringIO
    return (StringIO(url), len(url), url)
