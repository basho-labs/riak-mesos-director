REPO            ?= riak-mesos-director
RELDIR          ?= riak_mesos_director
PKG_VERSION	    ?= $(shell git describe --tags --abbrev=0 | tr - .)
ARCH            ?= amd64
OS_FAMILY          ?= ubuntu
OS_VERSION       ?= 14.04
PKGNAME         ?= $(RELDIR)-$(PKG_VERSION)-$(OS_FAMILY)-$(OS_VERSION)-$(ARCH).tar.gz
OAUTH_TOKEN     ?= $(shell cat oauth.txt)
GIT_TAG   	    ?= $(shell git describe --tags --abbrev=0)
RELEASE_ID      ?= $(shell curl -sS https://api.github.com/repos/basho-labs/$(REPO)/releases/tags/$(GIT_TAG)?access_token=$(OAUTH_TOKEN) | python -c 'import sys, json; print json.load(sys.stdin)["id"]')
DEPLOY_BASE     ?= "https://uploads.github.com/repos/basho-labs/$(REPO)/releases/$(RELEASE_ID)/assets?access_token=$(OAUTH_TOKEN)&name=$(PKGNAME)"
DOWNLOAD_BASE   ?= https://github.com/basho-labs/$(REPO)/releases/download/$(GIT_TAG)/$(PKGNAME)

BASE_DIR            = $(shell pwd)
ERLANG_BIN          = $(shell dirname $(shell which erl))
REBAR               ?= $(BASE_DIR)/rebar
OVERLAY_VARS        ?=

ifneq (,$(shell whereis sha256sum | awk '{print $2}';))
SHASUM = sha256sum
else
SHASUM = shasum -a 256
endif

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
	tar -C rel -czf $(PKGNAME) $(RELDIR)/
	mv $(PKGNAME) packages/
	cd packages && $(SHASUM) $(PKGNAME) > $(PKGNAME).sha
	cd packages && echo "$(DOWNLOAD_BASE)" > remote.txt
	cd packages && echo "$(BASE_DIR)/packages/$(PKGNAME)" > local.txt

sync-test:
	echo $(RELEASE_ID)

sync:
	echo "Uploading to "$(DOWNLOAD_BASE)
	cd packages && \
		curl -sS -XPOST -H 'Content-Type: application/gzip' $(DEPLOY_BASE) --data-binary @$(PKGNAME) && \
		curl -sS -XPOST -H 'Content-Type: application/octet-stream' $(DEPLOY_BASE).sha --data-binary @$(PKGNAME).sha

ASSET_ID        ?= $(shell curl -sS https://api.github.com/repos/basho-labs/$(REPO)/releases/$(RELEASE_ID)/assets?access_token=$(OAUTH_TOKEN) | python -c 'import sys, json; print "".join([str(asset["id"]) if asset["name"] == "$(PKGNAME)" else "" for asset in json.load(sys.stdin)])')
ASSET_SHA_ID    ?= $(shell curl -sS https://api.github.com/repos/basho-labs/$(REPO)/releases/$(RELEASE_ID)/assets?access_token=$(OAUTH_TOKEN) | python -c 'import sys, json; print "".join([str(asset["id"]) if asset["name"] == "$(PKGNAME).sha" else "" for asset in json.load(sys.stdin)])')
DELETE_DEPLOY_BASE     ?= "https://api.github.com/repos/basho-labs/$(REPO)/releases/assets/$(ASSET_ID)?access_token=$(OAUTH_TOKEN)"
DELETE_SHA_DEPLOY_BASE ?= "https://api.github.com/repos/basho-labs/$(REPO)/releases/assets/$(ASSET_SHA_ID)?access_token=$(OAUTH_TOKEN)"

sync-delete:
	echo "Deleting "$(DOWNLOAD_BASE)
	- $(shell curl -sS -XDELETE $(DELETE_DEPLOY_BASE))
	- $(shell curl -sS -XDELETE $(DELETE_SHA_DEPLOY_BASE))
