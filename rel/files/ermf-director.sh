#!/bin/bash

main() {
    echo "Running checks for proper environment:"
    echo "Checking if HOME is set..."
    if [ -z "$HOME" ]; then
        export HOME=`eval echo "~$WHOAMI"`
    fi

    NODENAME="$DIRECTOR_FRAMEWORK-$DIRECTOR_CLUSTER-director@127.0.0.1"
    sed -i "s,nodename = riak_mesos_director@127.0.0.1,nodename = $NODENAME,g" riak_mesos_director/etc/director.conf

    echo "Starting director..."
    riak_mesos_director/bin/director console -noinput #-no_epmd
}

main "$@"
