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

-module(rmd_wm).
-export([routes/0, dispatch/0]).
-export([init/1]).
-export([service_available/2,
         allowed_methods/2,
         content_types_provided/2,
         content_types_accepted/2,
         resource_exists/2,
         accept_content/2,
         provide_content/2]).

-record(ctx, {framework, cluster, uri_end, method, response=undefined}).

-include_lib("webmachine/include/webmachine.hrl").
-include("riak_mesos_director.hrl").

-define(status(),
    #ctx{method='GET', uri_end="status"}).
-define(configure(Framework, Cluster),
    #ctx{method='PUT', framework=Framework, cluster=Cluster, uri_end=Cluster}).
-define(frameworks(),
    #ctx{method='GET', uri_end="frameworks"}).
-define(clusters(),
    #ctx{method='GET', uri_end="clusters"}).
-define(nodes(),
    #ctx{method='GET', uri_end="nodes"}).
-define(health(),
    #ctx{method='GET', uri_end="health"}).

%%%===================================================================
%%% API
%%%===================================================================

routes() ->
     [["status"],% GET
      ["frameworks",framework,"clusters",cluster], % PUT
      ["frameworks"], % GET
      ["clusters"], % GET
      ["nodes"], % GET
      ["health"]]. % GET

dispatch() -> lists:map(fun(Route) -> {Route, ?MODULE, []} end, routes()).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init(_) ->
    {ok, #ctx{}}.

service_available(RD, Ctx0) ->
    Ctx1 = Ctx0#ctx{
        framework = wrq:path_info(framework, RD),
        cluster = wrq:path_info(cluster, RD),
        uri_end = lists:last(string:tokens(wrq:path(RD), "/")),
        method = wrq:method(RD)},

    lager:info("CTX: ~p~n", [Ctx1]),
    {true, RD, Ctx1}.

allowed_methods(RD, Ctx) ->
    Methods = ['GET', 'PUT'],
    {Methods, RD, Ctx}.

content_types_provided(RD, Ctx) ->
    Types = [{"application/json", provide_content}],
    {Types, RD, Ctx}.

content_types_accepted(RD, Ctx) ->
    Types = [{"application/json", accept_content}],
    {Types, RD, Ctx}.

resource_exists(RD, Ctx=?status()) ->
    Response = [{status, rmd_server:get_status()}],
    {true, RD, Ctx#ctx{response=Response}};
resource_exists(RD, Ctx=?configure(Framework, Cluster)) ->
    rmd_server:configure(Framework, Cluster),
    {true, RD, Ctx};
resource_exists(RD, Ctx=?frameworks()) ->
    Response = [{frameworks, rmd_server:get_riak_frameworks()}],
    {true, RD, Ctx#ctx{response=Response}};
resource_exists(RD, Ctx=?clusters()) ->
    Response = [{clusters, rmd_server:get_riak_clusters()}],
    {true, RD, Ctx#ctx{response=Response}};
resource_exists(RD, Ctx=?nodes()) ->
    Response = [{nodes, rmd_server:get_riak_nodes()}],
    {true, RD, Ctx#ctx{response=Response}};
resource_exists(RD, Ctx=?health()) ->
    %% Hacky: Keep the Riak explorer adhoc cluster up to date by hitting an endpoint which refreshes
    %% the node list.
    rmd_server:touch_riak_explorer(),
    Response = [{status, <<"OK">>}],
    {true, RD, Ctx#ctx{response=Response}};
resource_exists(RD, Ctx) ->
    {false, RD, Ctx}.

accept_content(RD, Ctx=?configure(_Framework, _Cluster)) ->
    {true, RD, Ctx}.

provide_content(RD, Ctx=#ctx{response=Response}) ->
    render_json(Response, RD, Ctx).

%% ====================================================================
%% Private
%% ====================================================================

render_json(Data, RD, Ctx) ->
    Body = mochijson2:encode(Data),
    {Body, RD, Ctx}.
