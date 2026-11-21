extends Node
## ASH&LEAD -- networking façade.
##
## The match is always hosted by one peer ("host authority"). Bots, AI, physics,
## objectives and economy live there; clients receive 20 Hz snapshots and send
## inputs. Three transports are supported:
##   * LOCAL  -- solo / bots, no socket at all (default, fully featured)
##   * LAN    -- ENet (desktop builds)
##   * RELAY  -- WebSocket relay (browser builds; run tools/relay_server.js)
##
## Everything degrades gracefully: if a socket fails the match falls back to
## bots so the player is never stuck on a dead lobby.

signal peer_joined(peer_id: int, info: Dictionary)
signal peer_left(peer_id: int)
signal connected_to_host()
signal connection_failed(reason: String)
signal lobby_updated(players: Array)
signal snapshot_received(data: Dictionary)

const TRANSPORT_LOCAL := "local"
const TRANSPORT_ENET := "enet"
const TRANSPORT_WS := "ws"

const DEFAULT_PORT := 47800
const DEFAULT_RELAY_PORT := 9080
const RELAY_URL := "wss://relay.ashandlead.game/ws"
const SNAPSHOT_HZ := 20.0

var transport := TRANSPORT_LOCAL
var is_host := true
var local_peer_id := 1
var lobby: Array[Dictionary] = []
var room_code := ""
var host_name := "HOST"
var _snap_accum := 0.0
var latency_ms := 0
var max_players := 12
var display_name := "ИГРОК"
var last_error := ""
## Set by NetSession during a match so the RPC entry points can reach it.
var match_hook: Object = null
var _ping_accum := 0.0


func _ready() -> void:
	set_process(true)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func reset_local() -> void:
	transport = TRANSPORT_LOCAL
	is_host = true
	local_peer_id = 1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	lobby.clear()
	lobby.append(_local_member())
	_lobby_changed()


func _local_member() -> Dictionary:
	return {
		"id": 1, "name": display_name, "team": 0, "ready": true, "bot": false,
		"kills": 0, "deaths": 0, "ping": 0, "is_host": true,
	}


# ---------------------------------------------------------------------------
# HOSTING / JOINING
# ---------------------------------------------------------------------------

func host_lan(port: int = DEFAULT_PORT) -> String:
	local_peer_id = 1
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		last_error = "Не удалось открыть порт %d (код %d)" % [port, err]
		return last_error
	multiplayer.multiplayer_peer = peer
	transport = TRANSPORT_ENET
	is_host = true
	local_peer_id = 1
	lobby.clear()
	lobby.append(_local_member())
	_lobby_changed()
	return ""


func join_lan(ip: String, port: int = DEFAULT_PORT) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		last_error = "Не удалось подключиться к %s:%d (код %d)" % [ip, port, err]
		return last_error
	multiplayer.multiplayer_peer = peer
	transport = TRANSPORT_ENET
	is_host = false
	local_peer_id = 0
	return ""


func host_relay(url: String = RELAY_URL) -> String:
	if url.begins_with("ws://") or url.begins_with("wss://"):
		# A URL points at an external relay: the browser host must be served by
		# tools/relay_server.js, which pairs peers by room. In-editor hosting is
		# port-based, so fall back to the default relay port.
		last_error = "Веб-реле запускается отдельно: node tools/relay_server.js (порт %d)" % DEFAULT_RELAY_PORT
		return last_error
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_RELAY_PORT)
	if err != OK:
		last_error = "Реле не поднялось (%d)" % err
		return last_error
	multiplayer.multiplayer_peer = peer
	transport = TRANSPORT_WS
	is_host = true
	local_peer_id = 1
	lobby.clear()
	lobby.append(_local_member())
	_lobby_changed()
	return ""


func join_relay(url: String, code: String = "") -> String:
	var peer := WebSocketMultiplayerPeer.new()
	var target := url
	if code != "":
		target = url.rstrip("/") + "/" + code
	var err := peer.create_client(target)
	if err != OK:
		last_error = "Не удалось подключиться к реле (%d)" % err
		return last_error
	multiplayer.multiplayer_peer = peer
	transport = TRANSPORT_WS
	is_host = false
	local_peer_id = 0
	return ""


func disconnect_all() -> void:
	reset_local()


# ---------------------------------------------------------------------------
# LOBBY
# ---------------------------------------------------------------------------

func _lobby_changed() -> void:
	lobby_updated.emit(lobby.duplicate(true))


func set_my_team(team: int) -> void:
	var me := _find_member(local_peer_id if not is_host else 1)
	if me.is_empty():
		return
	me["team"] = team
	_lobby_changed()
	rpc_any("member_team", int(me.get("id", 1)), team)


## Team flip applied on every peer (host authoritative).
@rpc("any_peer", "call_remote", "reliable")
func member_team(peer_id: int, team: int) -> void:
	var m := _find_member(peer_id)
	if m.is_empty():
		return
	m["team"] = team
	_lobby_changed()


func set_my_ready(ready: bool) -> void:
	var me := _find_member(local_peer_id if not is_host else 1)
	if me.is_empty():
		return
	me["ready"] = ready
	_lobby_changed()
	rpc_any("sync_member", me)


func member_is_host(peer_id: int) -> bool:
	var m := _find_member(peer_id)
	return bool(m.get("is_host", false))


func _find_member(peer_id: int) -> Dictionary:
	for m in lobby:
		if int(m.get("id", -1)) == peer_id:
			return m
	return {}


@rpc("any_peer", "call_remote", "reliable")
func sync_member(info: Dictionary) -> void:
	var existing := _find_member(int(info.get("id", 0)))
	if existing.is_empty():
		lobby.append(info)
	else:
		existing.merge(info, true)
	_lobby_changed()


@rpc("any_peer", "call_remote", "reliable")
func member_announce(info: Dictionary) -> void:
	if is_host:
		var existing := _find_member(int(info.get("id", 0)))
		if existing.is_empty():
			lobby.append(info)
		else:
			existing.merge(info, true)
		rpc_any("lobby_state", lobby)


@rpc("any_peer", "call_remote", "reliable")
func ping_req(stamp: int) -> void:
	if is_host:
		rpc_id(multiplayer.get_remote_sender_id(), "ping_ack", stamp)


@rpc("any_peer", "call_remote", "reliable")
func ping_ack(stamp: int) -> void:
	latency_ms = int(Time.get_ticks_msec()) - stamp
	var me := _find_member(local_peer_id)
	if not me.is_empty():
		me["ping"] = latency_ms
	_lobby_changed()


@rpc("any_peer", "call_remote", "reliable")
func lobby_state(state: Array) -> void:
	lobby = state
	_lobby_changed()


## Sends an RPC on whichever transport is active, or calls it locally in solo.
func rpc_any(method: String, a = null, b = null, c = null) -> void:
	if transport == TRANSPORT_LOCAL:
		return
	if multiplayer.multiplayer_peer == null:
		return
	if a == null:
		rpc(method)
	elif b == null:
		rpc(method, a)
	elif c == null:
		rpc(method, a, b)
	else:
		rpc(method, a, b, c)


# ---------------------------------------------------------------------------
# MATCH RPC ENTRY POINTS
# (RPC methods must live on a Node -- these forward into NetSession/MatchWorld)
# ---------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func net_roster(payload: Dictionary) -> void:
	if match_hook != null and match_hook.has_method("_client_roster"):
		match_hook.call("_client_roster", payload)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_input(packet: Dictionary) -> void:
	if match_hook != null and match_hook.has_method("_host_input"):
		match_hook.call("_host_input", multiplayer.get_remote_sender_id(), packet)


@rpc("any_peer", "call_remote", "reliable")
func net_order(packet: Dictionary) -> void:
	if match_hook != null and match_hook.has_method("_host_order"):
		match_hook.call("_host_order", multiplayer.get_remote_sender_id(), packet)


# ---------------------------------------------------------------------------
# SNAPSHOTS
# ---------------------------------------------------------------------------

func publish_snapshot(data: Dictionary) -> void:
	if transport == TRANSPORT_LOCAL:
		return
	rpc_any("client_snapshot", data)


@rpc("authority", "call_remote", "unreliable_ordered")
func client_snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)


func _process(delta: float) -> void:
	if transport == TRANSPORT_LOCAL:
		return
	_snap_accum += delta
	if not is_host and multiplayer.multiplayer_peer != null:
		var p := multiplayer.multiplayer_peer
		if p is WebSocketMultiplayerPeer or p is ENetMultiplayerPeer:
			pass
	if not is_host and multiplayer.multiplayer_peer != null:
		# ping the host once per second
		_ping_accum += delta
		if _ping_accum >= 1.0:
			_ping_accum = 0.0
			rpc_any("ping_req", int(Time.get_ticks_msec()))


func _on_peer_connected(id: int) -> void:
	# every peer refreshes its own roster, the host is authoritative
	if local_peer_id == 0:
		local_peer_id = multiplayer.get_unique_id()
	if is_host:
		var info := {
			"id": id, "name": "ПОДКЛЮЧЕН %d" % id, "team": 0, "ready": false,
			"bot": false, "kills": 0, "deaths": 0, "ping": 0, "is_host": false,
		}
		lobby.append(info)
		rpc_any("lobby_state", lobby)
		_lobby_changed()
	peer_joined.emit(id, _find_member(id))


func _on_peer_disconnected(id: int) -> void:
	for i in range(lobby.size()):
		if int(lobby[i].get("id", 0)) == id:
			lobby.remove_at(i)
			break
	_lobby_changed()
	peer_left.emit(id)


func _on_connected() -> void:
	local_peer_id = multiplayer.get_unique_id()
	connected_to_host.emit()
	rpc_id(1, "member_announce", {
		"id": local_peer_id, "name": display_name, "team": 0, "ready": false,
		"bot": false, "kills": 0, "deaths": 0, "ping": 0, "is_host": false,
	})


func _on_connection_failed() -> void:
	last_error = "Сервер не ответил."
	connection_failed.emit(last_error)


func _on_server_disconnected() -> void:
	last_error = "Соединение с хостом потеряно."
	connection_failed.emit(last_error)


# ---------------------------------------------------------------------------
# ROOM CODE / BOOKKEEPING
# ---------------------------------------------------------------------------

static func make_room_code() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(4):
		code += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	code += "-"
	for i in range(4):
		code += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return code


## True when the local peer is inside a match-capable session with real peers.
func is_online() -> bool:
	return transport != TRANSPORT_LOCAL and multiplayer.multiplayer_peer != null


## Human peers (bots are not in the lobby when filling happens on the host).
func human_count() -> int:
	var n := 0
	for m in lobby:
		if not bool(m.get("bot", false)):
			n += 1
	return n


## Transport-agnostic peer id for the local player inside a match.
func my_peer_id() -> int:
	if transport == TRANSPORT_LOCAL:
		return 1
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1
