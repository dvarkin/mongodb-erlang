%%%-------------------------------------------------------------------
%%% @author tihon
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 29. Дек. 2014 15:40
%%%-------------------------------------------------------------------
-module(mc_auth).
-author("tihon").

-include("mongo_protocol.hrl").

%% API
-export([auth/5, connect_to_database/1]).

%% Make connection to database and return socket
-spec connect_to_database(proplists:proplist()) -> {ok, port()} | {error, inet:posix()}.
connect_to_database(Conf) ->  %TODO scram server-first auth case
  Timeout = mc_utils:get_value(timeout, Conf, infinity),
  Host = mc_utils:get_value(host, Conf, "127.0.0.1"),
  Port = mc_utils:get_value(port, Conf, 27017),
  SSL = mc_utils:get_value(ssl, Conf, false),
  SslOpts = mc_utils:get_value(ssl_opts, Conf, []),
  do_connect(Host, Port, Timeout, SSL, SslOpts).

%% Authorize on database synchronously
-spec auth(port(), binary() | undefined, binary() | undefined, binary(), module()) -> boolean().
auth(Socket, Login, Password, Database, NetModule) ->
  Version = get_version(Socket, Database, NetModule),
  do_auth(Version, Socket, Database, Login, Password, NetModule).


%% @private
%% Get server version. This is need to choose default authentication method.
-spec get_version(port(), binary(), module()) -> float().
get_version(_Socket, _Database, _SetOpts) ->
    3.2.
  %% {true, #{<<"version">> := Version}} = mc_worker_api:sync_command(Socket, Database, {<<"buildinfo">>, 1}, SetOpts),
  %% {VFloat, _} = string:to_float(binary_to_list(Version)),
  %% VFloat.

%% @private
-spec do_auth(float(), port(), binary(), binary() | undefined, binary() | undefined, module()) -> boolean().
do_auth(_, _, _, Login, Pass, _) when Login == undefined; Pass == undefined -> true; %do nothing
do_auth(Version, Socket, Database, Login, Password, NetModule) when Version > 2.7 ->  %new authorisation
  mc_auth_logic:scram_sha_1_auth(Socket, Database, Login, Password, NetModule);
do_auth(_, Socket, Database, Login, Password, NetModule) ->   %old authorisation
  mc_auth_logic:mongodb_cr_auth(Socket, Database, Login, Password, NetModule).

%% @private
do_connect(Host, Port, Timeout, true, Opts) ->
  {ok, _} = application:ensure_all_started(ssl),
  ssl:connect(Host, Port, [binary, {active, true}, {packet, raw}] ++ Opts, Timeout);
do_connect(Host, Port, Timeout, false, _) ->
  gen_tcp:connect(Host, Port, [binary, {active, true}, {packet, raw}], Timeout).
