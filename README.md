# riak-mesos-director

## Build

```
make rel
```

## Configure

`rel/riak_mesos_director/etc/director.conf`

```
...
## HTTP proxy for Riak
listener.proxy.http = 0.0.0.0:8098
## Protobuf proxy for Riak
listener.proxy.protobuf = 0.0.0.0:8087
## HTTP listener for director API
listener.web.http = 0.0.0.0:9000
## Zookeeper address
zookeeper.address = 33.33.33.2:2181
...
```

## Run

```
./rel/riak_mesos_director/bin/riak_mesos_director start
```

## Test

```
curl 'http://localhost:9000/director/frameworks/riak-mesos-go3/clusters/mycluster/nodes'
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

```
curl 'http://localhost:9000/director/frameworks/riak-mesos-go6/clusters/mycluster/synchronize_nodes'
```

Should return:

```
{
    "synchronize_nodes": {
        "added": {
            "http": "mycluster-32c28cff-5f9f-475c-9a3b-4b0bd4e51829-66@ubuntu.local",
            "protobuf": "mycluster-32c28cff-5f9f-475c-9a3b-4b0bd4e51829-66@ubuntu.local"
        },
        "removed": []
    }
}
```

Running the same command again should return:

```
{
    "synchronize_nodes": {
        "added": [],
        "removed": []
    }
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
