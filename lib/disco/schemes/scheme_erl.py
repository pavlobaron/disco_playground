def input_stream(fd, sze, url, params):
    """Opens a StringIO whose data is everything after the url scheme,
    which is an Erlang function call like 'module:fun/<STRING>'. Only one argument
    is accepted, thus the function needs to autonomously get its data
    based on this parameter, for example from the local Riak data node (see examples)
    using a bucket name. The Erlang function will be applied as
    "module, fun/0, [<STRING>]".

    The same function will be called on every available node, so the
    corresponding Erlang module needs to be on the path.

    Internally, erl.// can being transformed into whatever scheme Disco accepts.
    The dummy example returns raw://, containing
    the result of the called Erlang function. Riak stream example returns 
    queue://.
    """
    from cStringIO import StringIO
    return (StringIO(url), len(url), url)
