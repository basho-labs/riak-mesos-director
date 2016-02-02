REPO            ?= riak_mesos_director
PKG_VERSION	    ?= $(shell git describe --tags --abbrev=0 | tr - .)
MAJOR           ?= $(shell echo $(PKG_VERSION) | cut -d'.' -f1)
MINOR           ?= $(shell echo $(PKG_VERSION) | cut -d'.' -f2)
ARCH            ?= amd64
OSNAME          ?= ubuntu
OSVERSION       ?= trusty
DEPLOY_BASE  ?= riak-tools/$(REPO)/$(MAJOR).$(MINOR)/$(PKG_VERSION)/$(OSNAME)/$(OSVERSION)/
PKGNAME = $(REPO)-$(PKG_VERSION)-$(ARCH).tar.gz

BASE_DIR            = $(shell pwd)
ERLANG_BIN          = $(shell dirname $(shell which erl))
REBAR               ?= $(BASE_DIR)/rebar
OVERLAY_VARS        ?=

.PHONY: deps

all: compile
compile: deps
	$(REBAR) compile
recompile:
	$(REBAR) compile skip_deps=true
deps:
	$(REBAR) get-deps
clean: cleantest relclean
	-rm -rf packages
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


##
## Packaging targets
##
tarball: rel
	echo "Creating packages/"$(PKGNAME)
	mkdir -p packages
	tar -C rel -czf $(PKGNAME) $(REPO)/
	mv $(PKGNAME) packages/
	cd packages && shasum -a 256 $(PKGNAME) > $(PKGNAME).sha
sync:
	echo "Uploading to "$(DEPLOY_BASE)
	cd packages && \
		s3cmd put --acl-public $(PKGNAME) s3://$(DEPLOY_BASE) && \
		s3cmd put --acl-public $(PKGNAME).sha s3://$(DEPLOY_BASE)
