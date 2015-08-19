# Riak Mesos Director

The Riak Mesos Director is part of the [Apache Mesos](http://mesos.apache.org/) framework for [Riak KV](http://basho.com/products/riak-kv/), a distributed NoSQL key-value data store that offers high availability, fault tolerance, operational simplicity, and scalability. 

This repository is installed as part of the Mesos Framework, which is available [here](https://github.com/basho-labs/riak-mesos). There is no reason to build this project unless you would like to contribute to it.

**Note:** This project is an early proof of concept. The code is in an alpha release and there may be bugs, incomplete features, incorrect documentation or other discrepancies.


## Build

```
make rel
```

## Configure

`rel/riak_mesos_director/etc/director.conf`

```
...
## When set to 'on', enables HTTP admin api.
listener.web = on

## HTTP listener for director API
listener.web.http = 0.0.0.0:9000

## HTTP proxy for Riak
listener.proxy.http = 0.0.0.0:8098

## Protobuf proxy for Riak
listener.proxy.protobuf = 0.0.0.0:8087

## Zookeeper address
zookeeper.address = 33.33.33.2:2181

## Riak Mesos Framework instance name
framework.name = riak-mesos-go6

## Riak Mesos Framework cluster name
framework.cluster = mycluster
...
```

## Run

```
./rel/riak_mesos_director/bin/director start
```

## Admin CLI

```
./rel/riak_mesos_director/bin/director start
```

## Test

In addition to the CLI, there are similar web endpoints:

* GET `/status`
* PUT `/configure/frameworks/{framework}/clusters/{cluster}`
    * Change the framework and cluster to proxy on the fly
* GET `/frameworks`
* GET `/clusters`
* GET `/nodes`

```
curl 'http://localhost:9000/nodes'
```

Should return:

```
{
    "nodes": [
        {
            "http": {
                "host": "ubuntu.local",
                "port": 31415
            },
            "name": "mycluster-32c28cff-5f9f-475c-9a3b-4b0bd4e51829-66@ubuntu.local",
            "protobuf": {
                "host": "ubuntu.local",
                "port": 31416
            }
        }
    ]
}
```

Local port 8098 should now proxy to the pool of available nodes

```
curl 'http://localhost:8098/ping'
```

Should return:

```
OK
```
