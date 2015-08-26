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
         proxy_protobuf_host_port/0,
         proxy_explorer_host_port/0,
         explorer_host_port/0,
         explorer_host/0,
         explorer_port/0]).

-include("riak_mesos_director.hrl").

%%%===================================================================
%%% API
%%%===================================================================

zk_host_port() ->
    {DefaultH, DefaultP} = case application:get_env(riak_mesos_director, zk_address) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"33.33.33.2", 2181}
    end,
    case os:getenv("DIRECTOR_ZK") of
        false -> {DefaultH, DefaultP};
        ValueStr ->
            [H,P] = string:tokens(ValueStr, ":"),
            {H,list_to_integer(P)}
    end.

proxy_http_host_port() ->
    {Host, DefaultP} = case application:get_env(riak_mesos_director, listenter_proxy_http) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 8098}
    end,
    Port = case os:getenv("PORT0") of
        false -> DefaultP;
        P -> list_to_integer(P)
    end,
    {Host, Port}.

proxy_protobuf_host_port() ->
    {Host, DefaultP} = case application:get_env(riak_mesos_director, listenter_proxy_protobuf) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 8087}
    end,
    Port = case os:getenv("PORT1") of
        false -> DefaultP;
        P -> list_to_integer(P)
    end,
    {Host, Port}.

web_enabled() ->
    Default = case application:get_env(riak_mesos_director, listener_web) of
        {ok, true} -> true;
        _ -> false
    end,
    case os:getenv("DIRECTOR_WEB_ENABLED") of
        false -> Default;
        ValueStr -> list_to_atom(ValueStr)
    end.

web_host_port() ->
    {Host, DefaultP} = case application:get_env(riak_mesos_director, listenter_web_http) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 9000}
    end,
    Port = case os:getenv("PORT2") of
        false -> DefaultP;
        P -> list_to_integer(P)
    end,
    {Host, Port}.

proxy_explorer_host_port() ->
    {Host, DefaultP} = {"0.0.0.0", 9999},
    Port = case os:getenv("PORT3") of
        false -> DefaultP;
        P -> list_to_integer(P)
    end,
    {Host, Port}.

explorer_host_port() ->
    explorer_host() ++ ":" ++ explorer_port().

explorer_host() ->
    Host = case os:getenv("FRAMEWORK_HOST") of
        false -> framework_name() ++ ".marathon.mesos";
        H -> H
    end,
    Host.

explorer_port() ->
    Port = case os:getenv("FRAMEWORK_PORT") of
        false -> 9090;
        P -> list_to_integer(P)
    end,
    Port.

framework_name() ->
    Default = case application:get_env(riak_mesos_director, framework_name) of
        {ok, FrameworkName} -> FrameworkName;
        undefined -> exit("framework.name is a required value in director.conf")
    end,
    case os:getenv("DIRECTOR_FRAMEWORK") of
        false -> Default;
        ValueStr -> ValueStr
    end.

cluster_name() ->
    Default = case application:get_env(riak_mesos_director, cluster_name) of
        {ok, ClusterName} -> ClusterName;
        undefined -> exit("framework.cluster is a required value in director.conf")
    end,
    case os:getenv("DIRECTOR_CLUSTER") of
        false -> Default;
        ValueStr -> ValueStr
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
