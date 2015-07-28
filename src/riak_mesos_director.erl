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

-module(riak_mesos_director).
-behaviour(application).

-export([start/2, stop/1]).

-export([web_enabled/0,
         web_host_port/0,
         zk_host_port/0,
         framework_name/0,
         cluster_name/0,
         proxy_http_host_port/0,
         proxy_protobuf_host_port/0]).

-include("riak_mesos_director.hrl").

%%%===================================================================
%%% API
%%%===================================================================

web_enabled() ->
    case application:get_env(riak_mesos_director, listener_web) of
        {ok, true} -> true;
        _ -> false
    end.

web_host_port() ->
    case application:get_env(riak_mesos_director, listenter_web_http) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 9000}
    end.

zk_host_port() ->
    case application:get_env(riak_mesos_director, zk_address) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"33.33.33.2", 2181}
    end.

framework_name() ->
    case application:get_env(riak_mesos_director, framework_name) of
        {ok, FrameworkName} -> FrameworkName;
        undefined -> exit("framework.name is a required value in director.conf")
    end.

cluster_name() ->
    case application:get_env(riak_mesos_director, cluster_name) of
        {ok, ClusterName} -> ClusterName;
        undefined -> exit("framework.cluster is a required value in director.conf")
    end.

proxy_http_host_port() ->
    case application:get_env(riak_mesos_director, listenter_proxy_http) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 8098}
    end.

proxy_protobuf_host_port() ->
    case application:get_env(riak_mesos_director, listenter_proxy_protobuf) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 8087}
    end.

%%%===================================================================
%%% Callbacks
%%%===================================================================

start(_Type, _StartArgs) ->
    {ok, Pid} = rmd_sup:start_link(),
    rmd_cli:load_schema(),
    rmd_cli:register(),
    {ok, Pid}.

stop(_State) ->
    ok.
