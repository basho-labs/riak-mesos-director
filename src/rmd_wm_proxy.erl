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

-module(rmd_wm_proxy).
-export([routes/0, dispatch/0]).
-export([init/1]).
-export([service_available/2,
         allowed_methods/2,
         content_types_provided/2,
         resource_exists/2,
         provide_content/2]).

-record(ctx, {framework, cluster, response=undefined}).

-include_lib("webmachine/include/webmachine.hrl").
-include("riak_mesos_director.hrl").

-define(synchronize_nodes(Framework, Cluster),
    #ctx{framework=Framework, cluster=Cluster}).

%%%===================================================================
%%% API
%%%===================================================================

routes() ->
     [[?RMD_BASE_ROUTE] ++ ["frameworks"] ++ [framework] ++ ["clusters"] ++
        [cluster] ++ ["synchronize_nodes"]].

dispatch() -> lists:map(fun(Route) -> {Route, ?MODULE, []} end, routes()).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init(_) ->
    {ok, #ctx{}}.

service_available(RD, Ctx0) ->
    Ctx1 = Ctx0#ctx{
        framework = wrq:path_info(framework, RD),
        cluster = wrq:path_info(cluster, RD)},

    lager:info("CTX: ~p~n", [Ctx1]),
    {true, RD, Ctx1}.

allowed_methods(RD, Ctx) ->
    Methods = ['GET'],
    {Methods, RD, Ctx}.

content_types_provided(RD, Ctx) ->
    Types = [{"application/json", provide_content}],
    {Types, RD, Ctx}.

resource_exists(RD, Ctx=?synchronize_nodes(Framework, Cluster)) ->
    Response = [{synchronize_nodes, rmd_proxy:synchronize_nodes(Framework, Cluster)}],
    {true, RD, Ctx#ctx{response=Response}};
resource_exists(RD, Ctx) ->
    {false, RD, Ctx}.

provide_content(RD, Ctx=#ctx{response=Response}) ->
    render_json(Response, RD, Ctx).

%% ====================================================================
%% Private
%% ====================================================================

render_json(Data, RD, Ctx) ->
    Body = mochijson2:encode(Data),
    {Body, RD, Ctx}.
