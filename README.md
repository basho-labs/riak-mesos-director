# riak-mesos-director

## Build

```
make rel
```

## Configure

`rel/riak_mesos_director/etc/riak_mesos_director.conf`

```
...
listener.http = 0.0.0.0:9000
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
