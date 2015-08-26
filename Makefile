BASE_DIR         = $(shell pwd)
ERLANG_BIN       = $(shell dirname $(shell which erl))
REBAR           ?= $(BASE_DIR)/rebar
OVERLAY_VARS    ?=

.PHONY: deps

all: compile
compile: deps
	$(REBAR) compile
recompile:
	$(REBAR) compile skip_deps=true
deps:
	$(REBAR) get-deps
cleantest:
	rm -rf .eunit/*
test: cleantest
	$(REBAR)  skip_deps=true eunit
rel: relclean deps compile
	$(REBAR) compile
	$(REBAR) skip_deps=true generate $(OVERLAY_VARS)
	tail -n +4 rel/riak_mesos_director/lib/env.sh > rel/riak_mesos_director/lib/env.sh.tmp && mv rel/riak_mesos_director/lib/env.sh.tmp rel/riak_mesos_director/lib/env.sh
	cat env.sh.patch | cat - rel/riak_mesos_director/lib/env.sh > rel/riak_mesos_director/lib/env.sh.tmp && mv rel/riak_mesos_director/lib/env.sh.tmp rel/riak_mesos_director/lib/env.sh
relclean:
	rm -rf rel/riak_mesos_director
stage: rel
	$(foreach dep,$(wildcard deps/*), rm -rf rel/riak_mesos_director/lib/$(shell basename $(dep))-* && ln -sf $(abspath $(dep)) rel/riak_mesos_director/lib;)
	$(foreach app,$(wildcard apps/*), rm -rf rel/riak_mesos_director/lib/$(shell basename $(app))-* && ln -sf $(abspath $(app)) rel/riak_mesos_director/lib;)
