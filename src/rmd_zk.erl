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

-module(rmd_zk).
-behaviour(gen_server).

-export([start_link/1]).
-export([get_zk_frameworks/0,
         get_zk_framework/1,
         get_riak_clusters/1,
         get_riak_cluster/2,
         get_riak_nodes/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

-include("riak_mesos_director.hrl").
-include_lib("erlzk/include/erlzk.hrl").

-record(state, {zk}).

%%%===================================================================
%%% API
%%%===================================================================

start_link([ZKHost, ZKPort]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ZKHost, ZKPort], []).

get_zk_frameworks() ->
    gen_server:call(?MODULE, {get_zk_frameworks}).

get_zk_framework(Framework) ->
    gen_server:call(?MODULE, {get_zk_framework, Framework}).

get_riak_clusters(Framework) ->
    gen_server:call(?MODULE, {get_riak_clusters, Framework}).

get_riak_cluster(Framework, Cluster) ->
    gen_server:call(?MODULE, {get_riak_cluster, Framework, Cluster}).

%% TODO: Add a watch here to continually monitor nodes, not just on demand
get_riak_nodes(Framework, Cluster) ->
    gen_server:call(?MODULE, {get_riak_nodes, Framework, Cluster}).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init([ZKHost, ZKPort]) ->
    process_flag(trap_exit, true),
    %% TODO: get info from config
    {ok, Pid} = erlzk:connect([{ZKHost, ZKPort}], 30000),
    {ok, #state{zk=Pid}}.

handle_call({get_zk_frameworks}, _From, State=#state{zk=ZK}) ->
    Children = get_children(ZK, "/riak/frameworks"),
    {reply, Children, State};
handle_call({get_zk_framework, Framework}, _From, State=#state{zk=ZK}) ->
    ZKNode = lists:flatten(io_lib:format("/riak/frameworks/~s",[Framework])),
    Data = get_data(ZK, ZKNode),
    {reply, Data, State};
handle_call({get_riak_clusters, Framework}, _From, State=#state{zk=ZK}) ->
    ZKNode = lists:flatten(io_lib:format("/riak/frameworks/~s/clusters",[Framework])),
    Children = get_children(ZK, ZKNode),
    {reply, Children, State};
handle_call({get_riak_cluster, Framework, Cluster}, _From, State=#state{zk=ZK}) ->
    ZKNode = lists:flatten(io_lib:format("/riak/frameworks/~s/clusters/~s",[Framework, Cluster])),
    Data = get_data(ZK, ZKNode),
    {reply, Data, State};
handle_call({get_riak_nodes, Framework, Cluster}, _From, State=#state{zk=ZK}) ->
    ZKNode0 = lists:flatten(io_lib:format("/riak/frameworks/~s/clusters/~s/coordinator/coordinatedNodes",[Framework, Cluster])),
    CNodes = get_children(ZK, ZKNode0),

    F1 = fun(CNode, Acc) ->
        ZKNode1 = lists:flatten(io_lib:format("/riak/frameworks/~s/clusters/~s/coordinator/coordinatedNodes/~s",[Framework, Cluster, CNode])),
        NodeJson = get_data(ZK, ZKNode1),
        {struct,[{<<"NodeName">>,NodeName}]} = mochijson2:decode(NodeJson),
        [_, Host] = string:tokens(binary_to_list(NodeName), "@"),
        [{list_to_atom(binary_to_list(NodeName)), Host}|Acc] end,
    NodeNames = lists:foldl(F1, [], CNodes),

    F2 = fun({NodeName, Host}, Acc) ->
        {_, HTTPPort} = http_listener(NodeName),
        {_, PBPort} = pb_listener(NodeName),
        [[{name, NodeName},
         {protobuf,
           [{host, list_to_binary(Host)}, {port, PBPort}]},
         {http,
            [{host, list_to_binary(Host)}, {port, HTTPPort}]}]|Acc] end,
    Nodes = lists:foldl(F2, [], NodeNames),
    {reply, Nodes, State};
handle_call(_Message, _From, State) ->
    {reply, notfound, State}.

handle_cast(_Message, State) ->
    {noreply, State}.

handle_info({'EXIT', _Pid, _Reason}, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(Reason, _State) ->
    lager:error("rmd_zk terminated, reason: ~p", [Reason]),
    ok.

%%%===================================================================
%%% Private
%%%===================================================================

get_children(ZK, ZKNode) ->
    case erlzk:get_children(ZK, ZKNode) of
        {ok, Children} ->
            F1 = fun(Child, Acc) ->
                [list_to_binary(Child)|Acc] end,
            lists:foldl(F1, [], Children);
        {error, Reason} ->
            lager:error("Error getting children at node ~p: ~p", [ZKNode, Reason]),
            []
    end.

get_data(ZK, ZKNode) ->
    case erlzk:get_data(ZK, ZKNode) of
        {ok, {Data, _Stat}} -> Data;
        {error, Reason} ->
            lager:error("Error getting data at node ~p: ~p", [ZKNode, Reason]),
            []
    end.

http_listener(Node) ->
    {ok,[{Ip,Port}]} = remote(Node, application, get_env, [riak_api, http]),
    {Ip, Port}.

pb_listener(Node) ->
    {ok,[{Ip,Port}]} = remote(Node, application, get_env, [riak_api, pb]),
    {Ip, Port}.

remote(N, M, F, A) ->
    safe_rpc(N, M, F, A, 60000).

safe_rpc(Node, Module, Function, Args, Timeout) ->
    try rpc:call(Node, Module, Function, Args, Timeout) of
        Result ->
            Result
    catch
        'EXIT':{noproc, _NoProcDetails} ->
            {badrpc, rpc_process_down}
    end.
