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
    configure/3,
    list_frameworks/3,
    list_clusters/3,
    list_nodes/3
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

status(_Command, [], []) ->
    fmt(rmd_server:get_status()).

configure(_Command, [], [{framework, Framework},{cluster, Cluster}]) ->
    fmt(rmd_server:configure(Framework, Cluster)).

list_frameworks(_Command, [], []) ->
    fmt(rmd_server:get_riak_frameworks()).

list_clusters(_Command, [], []) ->
    fmt(rmd_server:get_riak_clusters()).

list_nodes(_Command, [], []) ->
    fmt(rmd_server:get_riak_nodes()).

%%%===================================================================
%%% Callbacks
%%%===================================================================

register_cli() ->
    clique:register_usage(
        ["director-admin"], usage()),
    clique:register_command(
        ["director-admin", "status"],[],[],fun status/3),
    clique:register_command(
        ["director-admin", "configure"],[],
         [{framework, [{shortname, "f"}, {longname, "framework"}]},
          {cluster,   [{shortname, "c"}, {longname, "cluster"}]}],
         fun configure/3),
    clique:register_command(
        ["director-admin", "list-frameworks"],[],[],fun list_frameworks/3),
    clique:register_command(
        ["director-admin", "list-clusters"],[],[],fun list_clusters/3),
    clique:register_command(
        ["director-admin", "list-nodes"],[],[],fun list_nodes/3).

%%%===================================================================
%%% Private
%%%===================================================================

usage() ->
    [
     "Usage: director-admin <sub-command>\n\n",
     "  Sub-commands:\n",
     "    status                            Display current information about the director\n",
     "    configure -f framework -c cluster Update and resynchronize proxy using the specified framework and cluster\n",
     "    list-frameworks                   List of running Riak Mesos Framework instance names\n",
     "    list-clusters                     List of running Riak clusters in the configured framework\n",
     "    list-nodes                        List of running Riak nodes in the configured cluster\n"
    ].

fmt([]) ->
    [clique_status:text("[]")];
fmt(JSON) ->
    [clique_status:text(mochijson2:encode(JSON))].
