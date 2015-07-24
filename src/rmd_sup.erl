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

-module(rmd_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).

-include("riak_mesos_director.hrl").


%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init([]) ->
    application:set_env(balance, initial_be_list, []),
    HTTP_PROXY = {balance_http,
        {bal_proxy, start_link, [proxy_http_config()]},
        permanent, 5000, worker, [bal_proxy, tcp_proxy]},
    PROTOBUF_PROXY = {balance_protobuf,
        {bal_proxy, start_link, [proxy_protobuf_config()]},
        permanent, 5000, worker, [bal_proxy, tcp_proxy]},
    RMD_ZK = {rmd_zk,
          {rmd_zk, start_link, [zk_config()]},
          permanent, 5000, worker, [rmd_zk]},
    Processes = [HTTP_PROXY, PROTOBUF_PROXY, RMD_ZK],
    {ok, { {one_for_one, 10, 10}, Processes} }.

%%%===================================================================
%%% Private
%%%===================================================================

proxy_http_config() ->
    {Ip, Port} = proxy_http_host_port(),
    [balance_http, Ip, Port, 5*1000,180*1000].

proxy_protobuf_config() ->
    {Ip, Port} = proxy_protobuf_host_port(),
    [balance_protobuf, Ip, Port, 5*1000,180*1000].

zk_config() ->
    {Ip, Port} = zk_host_port(),
    [Ip, Port, framework_name(), cluster_name()].

zk_host_port() ->
    case application:get_env(riak_mesos_director, zk_address) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"33.33.33.2", 2181}
    end.

framework_name() ->
    case application:get_env(riak_mesos_director, framework_name) of
        {ok, FrameworkName} -> FrameworkName;
        undefined -> exit("framework.name is a required value in riak_mesos_director.conf")
    end.

cluster_name() ->
    case application:get_env(riak_mesos_director, cluster_name) of
        {ok, ClusterName} -> ClusterName;
        undefined -> exit("framework.cluster is a required value in riak_mesos_director.conf")
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
