#!/bin/bash

main() {
    echo "Running checks for proper environment:"
    echo "Checking if HOME is set..."
    if [ -z "$HOME" ]; then
        export HOME=`eval echo "~$WHOAMI"`
    fi

    echo "Starting director..."
    riak_mesos_director/bin/director console -noinput #-no_epmd
}

main "$@"
