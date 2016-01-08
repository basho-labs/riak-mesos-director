BASE_DIR            = $(shell pwd)
ERLANG_BIN          = $(shell dirname $(shell which erl))
REBAR               ?= $(BASE_DIR)/rebar
OVERLAY_VARS        ?=
PACKAGE_VERSION     ?= 0.3.0
BUILD_DIR           ?= $(BASE_DIR)/_build
export PROJECT_BASE ?= riak-mesos
export DEPLOY_BASE  ?= riak-tools/$(PROJECT_BASE)
export DEPLOY_OS    ?= ubuntu
export OS_ARCH		  ?= linux_amd64

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


### Director Package begin
$(BUILD_DIR)/riak-mesos-director-$(OS_ARCH)-$(PACKAGE_VERSION).tar.gz: rel
	-rm -rf $(BUILD_DIR)/director
	mkdir -p $(BUILD_DIR)/director
	cp -R rel/riak_mesos_director/* $(BUILD_DIR)/director/
	echo "Thank you for downloading Riak Mesos Framework Director. Please visit https://github.com/basho-labs/riak-mesos-tools for usage information." > $(BUILD_DIR)/director/INSTALL.txt
	cd $(BUILD_DIR) && tar -zcvf riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz director
sync: sync_director
sync_director:
	cd $(BUILD_DIR)/ && \
		s3cmd put --acl-public riak_mesos_director_$(OS_ARCH)_$(PACKAGE_VERSION).tar.gz s3://$(DEPLOY_BASE)/$(DEPLOY_OS)/
clean: clean_riak_mesos_director
clean_riak_mesos_director:
	-rm -rf $(BUILD_DIR)/riak-mesos-director-$(OS_ARCH)-$(PACKAGE_VERSION).tar.gz $(BUILD_DIR)/director
### Director Package end

