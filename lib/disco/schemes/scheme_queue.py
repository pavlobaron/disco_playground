def input_stream(fd, sze, url, params):
    """Connects to RabbitMQ and listens to it.
    Results of a raw:// can be very many, so raw:// can flood memory.
    Thus, the riak stream example uses queue:// which will be filled with local
    vnode data.
    """
    from rabbitio import RabbitIO
    return (RabbitIO(url[8:], sze), sze, url)
