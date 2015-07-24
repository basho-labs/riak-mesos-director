%% -------------------------------------------------------------------
%%
%% Copyright (c) 2015 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(rmd_cli).

-behaviour(clique_handler).

-export([command/1]).

-export([
    register/0,
    load_schema/0]).

-export([
    status/3,
    framework_status/3,
    framework_names/3,
    framework_clusters/3,
    framework_nodes/3,
    proxy_status/3,
    proxy_synchronize/3
]).

-export([register_cli/0]).

%%%===================================================================
%%% API
%%%===================================================================

command(Cmd) ->
    clique:run(Cmd).

register() ->
    clique:register([?MODULE]).

load_schema() ->
    case application:get_env(riak_mesos_director, schema_dirs) of
        {ok, Directories} ->
            ok = clique_config:load_schema(Directories);
        _ ->
            ok = clique_config:load_schema([code:lib_dir()])
    end.

status(_Command, [], []) -> fmt("Not Yet Implemented").

framework_status(_Command, [], []) -> fmt("Not Yet Implemented").
framework_names(_Command, [], []) -> fmt(rmd_server:get_zk_frameworks()).
framework_clusters(_Command, [], []) ->
    fmt(rmd_server:get_riak_clusters());
framework_clusters(_Command, [], [{framework, Framework}]) ->
    fmt(rmd_server:get_riak_clusters(Framework)).
framework_nodes(_Command, [], []) ->
    fmt(rmd_server:get_riak_nodes());
framework_nodes(_Command, [], [{framework, Framework},{cluster, Cluster}]) ->
    fmt(rmd_server:get_riak_nodes(Framework, Cluster)).

proxy_status(_Command, [], []) -> fmt(rmd_server:get_proxy_status()).
proxy_synchronize(_Command, [], []) ->
    fmt(rmd_server:synchronize_riak_nodes());
proxy_synchronize(_Command, [], [{framework, Framework},{cluster, Cluster}]) ->
    fmt(rmd_server:synchronize_riak_nodes(Framework, Cluster)).

%%%===================================================================
%%% Callbacks
%%%===================================================================

register_cli() ->
    clique:register_usage(["director-admin"], usage()),
    clique:register_command(["director-admin", "status"],[],[],fun status/3),

    clique:register_usage(["director-admin", "framework"], framework_usage()),
    clique:register_command(
        ["director-admin", "framework", "status"],[],[],fun framework_status/3),
    clique:register_command(
        ["director-admin", "framework", "names"],[],[],fun framework_names/3),
    clique:register_command(
        ["director-admin", "framework", "clusters"],[],
         [{framework, [{shortname, "f"}, {longname, "framework"}]}],
         fun framework_clusters/3),
    clique:register_command(
        ["director-admin", "framework", "nodes"],[],
         [{framework, [{shortname, "f"}, {longname, "framework"}]},
          {cluster,   [{shortname, "c"}, {longname, "cluster"}]}],
         fun framework_nodes/3),

    clique:register_usage(["director-admin", "proxy"], proxy_usage()),
    clique:register_command(["director-admin", "proxy", "status"],[],[],fun proxy_status/3),
    clique:register_command(["director-admin", "proxy", "synchronize"],[],
        [{framework, [{shortname, "f"}, {longname, "framework"}]},
         {cluster,   [{shortname, "c"}, {longname, "cluster"}]}],fun proxy_synchronize/3).

%%%===================================================================
%%% Private
%%%===================================================================

usage() ->
    [
     "Usage: director-admin { status | framework | proxy }\n",
     "  Use --help after a sub-command for more details.\n"
    ].

framework_usage() ->
    [
     "director-admin framework <sub-command>\n\n",
     "  Display Riak Mesos Framework information.\n\n",
     "  Sub-commands:\n",
     "    status                        Display current framework status and information\n",
     "    names                         Display a list of running Riak Mesos Framework instance names\n",
     "    clusters -f framework         Display a list of running Riak clusters in the Mesos Framework\n",
     "    nodes -f framework -c cluster Display a list of running Riak nodes in the Mesos Framework\n",
     "  Use --help after a sub-command for more details.\n"
    ].

proxy_usage() ->
    [
     "director-admin proxy <sub-command>\n\n",
     "  Display Riak Mesos Director proxy information.\n\n",
     "  Sub-commands:\n",
     "    status            Display current proxy and connection information\n",
     "    synchronize       Force a re-synchronization of Riak nodes proxied\n",
     "  Use --help after a sub-command for more details.\n"
    ].

fmt([]) ->
    [clique_status:text("[]")];
fmt(JSON) ->
    [clique_status:text(mochijson2:encode(JSON))].
