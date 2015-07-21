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
    RMD_ZK = {rmd_zk,
          {rmd_zk, start_link, [zk_config()]},
          permanent, 5000, worker, [rmd_zk]},
    Web = {webmachine_mochiweb,
           {webmachine_mochiweb, start, [web_config()]},
           permanent, 5000, worker, [mochiweb_socket_server]},
    Processes = [RMD_ZK, Web],
    {ok, { {one_for_one, 10, 10}, Processes} }.

%%%===================================================================
%%% Private
%%%===================================================================

zk_config() ->
    {Ip, Port} = zk_host_port(),
    [Ip, Port].

web_config() ->
    {Ip, Port} = web_host_port(),
    WebConfig0 = [
        {ip, Ip},
        {port, Port},
        {nodelay, true},
        {log_dir, "log"},
        {dispatch, dispatch()}
    ],
    WebConfig1 = case application:get_env(riak_mesos_director, ssl) of
        {ok, SSLOpts} ->
            WebConfig0 ++ [{ssl, true}, {ssl_opts, SSLOpts}];
        undefined ->
            WebConfig0
    end,
    WebConfig1.

zk_host_port() ->
    case application:get_env(riak_mesos_director, zk_address) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"33.33.33.2", 2181}
    end.

web_host_port() ->
    case application:get_env(riak_mesos_director, listenter_http) of
        {ok, {_, _} = HostPort} -> HostPort;
        undefined -> {"0.0.0.0", 9000}
    end.

dispatch() -> lists:flatten(dispatch(resources(), [])).

dispatch([], Accum) ->
    lists:reverse(Accum);
dispatch([M | Rest], Accum) ->
    dispatch(Rest, [M:dispatch() | Accum]).

resources() ->
    [
        rmd_wm_base,
        rmd_wm_node
    ].
