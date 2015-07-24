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

-module(rmd_server).
-behaviour(gen_server).

-export([start_link/1]).
-export([get_zk_frameworks/0,
         get_zk_framework/0,get_zk_framework/1,
         get_riak_clusters/0,get_riak_clusters/1,
         get_riak_cluster/0,get_riak_cluster/2,
         get_riak_nodes/0,get_riak_nodes/2,
         synchronize_riak_nodes/0,synchronize_riak_nodes/2,
         watch_riak_nodes/0,watch_riak_nodes/2,
         get_proxy_status/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

-include("riak_mesos_director.hrl").
-include_lib("erlzk/include/erlzk.hrl").
-include_lib("balance/include/balance.hrl").

-record(state, {zk}).

%%%===================================================================
%%% API
%%%===================================================================

start_link(Args) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Args, []).

get_zk_frameworks() ->
    gen_server:call(?MODULE, {get_zk_frameworks}).
get_zk_framework() ->
    get_zk_framework(riak_mesos_director:framework_name()).
get_zk_framework(Framework) ->
    gen_server:call(?MODULE, {get_zk_framework, Framework}).

get_riak_clusters() ->
    get_riak_clusters(riak_mesos_director:framework_name()).
get_riak_clusters(Framework) ->
    gen_server:call(?MODULE, {get_riak_clusters, Framework}).
get_riak_cluster() ->
    get_riak_cluster(riak_mesos_director:framework_name(), riak_mesos_director:cluster_name()).
get_riak_cluster(Framework, Cluster) ->
    gen_server:call(?MODULE, {get_riak_cluster, Framework, Cluster}).

get_riak_nodes() ->
    get_riak_nodes(riak_mesos_director:framework_name(), riak_mesos_director:cluster_name()).
get_riak_nodes(Framework, Cluster) ->
    gen_server:call(?MODULE, {get_riak_nodes, Framework, Cluster}).
synchronize_riak_nodes() ->
    synchronize_riak_nodes(riak_mesos_director:framework_name(), riak_mesos_director:cluster_name()).
synchronize_riak_nodes(Framework, Cluster) ->
    gen_server:call(?MODULE, {synchronize_riak_nodes, Framework, Cluster}).
watch_riak_nodes() ->
    watch_riak_nodes(riak_mesos_director:framework_name(), riak_mesos_director:cluster_name()).
watch_riak_nodes(Framework, Cluster) ->
    gen_server:cast(?MODULE, {watch_riak_nodes, Framework, Cluster}).

get_proxy_status() ->
    gen_server:call(?MODULE, {get_proxy_status}).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init([ZKHost, ZKPort, Framework, Cluster]) ->
    process_flag(trap_exit, true),
    {ok, ZK} = erlzk:connect([{ZKHost, ZKPort}], 30000),
    ZKNode = coordinated_nodes_zknode(Framework, Cluster),
    do_synchronize_riak_nodes(ZK, ZKNode),
    do_watch_riak_nodes(ZK, ZKNode),
    {ok, #state{zk=ZK}}.

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
    ZKNode = coordinated_nodes_zknode(Framework, Cluster),
    Nodes = do_get_riak_nodes(ZK, ZKNode),
    {reply, Nodes, State};
handle_call({get_proxy_status}, _From, State) ->
    F1 = fun(St, Acc0) ->
        F2 = fun(Node, Acc1) ->
            N = [{id, Node#be.id},
            {name, list_to_binary(Node#be.name)},
            {port, Node#be.port},
            {status, Node#be.status},
            {maxconn, Node#be.maxconn},
            {pendconn, Node#be.pendconn},
            {actconn, Node#be.actconn},
            {lasterr, Node#be.lasterr},
            {lasterrtime, Node#be.lasterrtime},
            {act_count, Node#be.act_count},
            {act_time, Node#be.act_time}],
            % {pidlist, Node#be.pidlist}],
            [N|Acc1]
        end,
        Nodes = lists:foldl(F2, [], St#bp_state.be_list),

        P = [{name, St#bp_state.register_name},
        {local_ip, list_to_binary(St#bp_state.local_ip)},
        {local_port, St#bp_state.local_port},
        {conn_timeout, St#bp_state.conn_timeout},
        {act_timeout, St#bp_state.act_timeout},
        {nodes, Nodes}],
        % {acceptor, St#bp_state.acceptor},
        % {start_time, St#bp_state.start_time},
        % {to_timer, St#bp_state.to_timer},
        % {wait_list, St#bp_state.wait_list}],
        [P|Acc0]
    end,
    Status = lists:foldl(F1, [], [
        bal_proxy:get_state(balance_http),
        bal_proxy:get_state(balance_protobuf)]),
    {reply, Status, State};
handle_call({synchronize_riak_nodes, Framework, Cluster}, _From, State=#state{zk=ZK}) ->
    ZKNode = coordinated_nodes_zknode(Framework, Cluster),
    Changes = do_synchronize_riak_nodes(ZK, ZKNode),
    lager:info("Synchronized Riak nodes, changes: ~p", [Changes]),
    {reply, Changes, State};
handle_call(Message, _From, State) ->
    lager:error("Received undefined message in call: ~p", [Message]),
    {reply, {error, undefined_message}, State}.

handle_cast({watch_riak_nodes, Framework, Cluster}, State=#state{zk=ZK}) ->
    ZKNode = coordinated_nodes_zknode(Framework, Cluster),
    do_watch_riak_nodes(ZK, ZKNode),
    {noreply, State};
handle_cast(_Message, State) ->
    {noreply, State}.

handle_info({'EXIT', _Pid, _Reason}, State) ->
    {noreply, State};
handle_info({get_children, ZKNodeBin, node_children_changed}=Message, State=#state{zk=ZK}) ->
    ZKNode = binary_to_list(ZKNodeBin),
    lager:info("Received coordinated node change event: ~p. Synchronizing Riak Nodes...", [Message]),
    Changes = do_synchronize_riak_nodes(ZK, ZKNode),
    lager:info("Synchronized Riak nodes, changes: ~p", [Changes]),
    erlzk:get_children(ZK, ZKNode, self()),
    {noreply, State};
handle_info(Message, State) ->
    lager:warning("Received unknown message: ~p", [Message]),
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(Reason, _State) ->
    lager:error("rmd_server terminated, reason: ~p", [Reason]),
    ok.

%%%===================================================================
%%% Private
%%%===================================================================

coordinated_nodes_zknode(Framework, Cluster) ->
    lists:flatten(io_lib:format("/riak/frameworks/~s/clusters/~s/coordinator/coordinatedNodes",[Framework, Cluster])).

do_get_riak_nodes(ZK, ZKNode0) ->
    CNodes = get_children(ZK, ZKNode0),

    F1 = fun(CNode, Acc) ->
        ZKNode1 = lists:flatten(io_lib:format("~s/~s",[ZKNode0, CNode])),
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
    Nodes.

do_synchronize_riak_nodes(ZK, ZKNode) ->
    AvailableNodes = do_get_riak_nodes(ZK, ZKNode),
    HTTPSt = bal_proxy:get_state(balance_http),
    ProxyHTTPNodes = HTTPSt#bp_state.be_list,
    PBSt = bal_proxy:get_state(balance_protobuf),
    ProxyPBNodes = PBSt#bp_state.be_list,

    F1 = fun([{name, NodeName},
              {protobuf,[{host, Host}, {port, PBPort}]},
              {http,[{host, Host}, {port, HTTPPort}]}], Acc0) ->
          Acc1 = case bal_proxy:get_host(balance_http, NodeName) of
              false ->
                HTTPBe = #be{id=NodeName, name=binary_to_list(Host), port=HTTPPort, status=up, maxconn=1024, lasterr=no_error, lasterrtime=0},
                lager:info("Adding ~p to http proxy", [NodeName]),
                bal_proxy:add_be(balance_http, HTTPBe, ""),
                [{http, NodeName} | Acc0];
              _ -> Acc0
          end,
          Acc2 = case bal_proxy:get_host(balance_protobuf, NodeName) of
              false ->
                PBBe = #be{id=NodeName, name=binary_to_list(Host), port=PBPort, status=up, maxconn=1024, lasterr=no_error, lasterrtime=0},
                lager:info("Adding ~p to protobuf proxy", [NodeName]),
                bal_proxy:add_be(balance_protobuf, PBBe, ""),
                [{protobuf, NodeName} | Acc1];
              _ -> Acc1
          end,
          Acc2
    end,
    Added = lists:foldl(F1, [], AvailableNodes),

    %% TODO: Mark as down, and wait until all active connections are gone
    %% before deleting
    F2 = fun(#be{id=NodeName}, Acc0) ->
        case riak_node_is_available(NodeName, AvailableNodes) of
            false ->
                lager:info("Removing ~p from http proxy", [NodeName]),
                bal_proxy:del_be(balance_http, NodeName),
                [{http, NodeName}|Acc0];
            _ -> Acc0
        end
    end,
    RemovedHTTP = lists:foldl(F2, [], ProxyHTTPNodes),

    %% TODO: Mark as down, and wait until all active connections are gone
    %% before deleting
    F3 = fun(#be{id=NodeName}, Acc0) ->
        case riak_node_is_available(NodeName, AvailableNodes) of
            false ->
                lager:info("Removing ~p from protobuf proxy", [NodeName]),
                bal_proxy:del_be(balance_pb, NodeName),
                [{protobuf, NodeName}|Acc0];
            _ -> Acc0
        end
    end,
    RemovedPB = lists:foldl(F3, [], ProxyPBNodes),
    [{added, Added}, {removed, RemovedHTTP ++ RemovedPB}].

do_watch_riak_nodes(ZK, ZKNode) ->
    erlzk:get_children(ZK, ZKNode, self()).

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

riak_node_is_available(_, []) -> false;
riak_node_is_available(Id, [[{name, Id}|_]|_]) -> true;
riak_node_is_available(Id, [[{name, _}|_]|Rest]) -> riak_node_is_available(Id, Rest).
