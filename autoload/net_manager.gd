extends Node
## LAN / direct-IP multiplayer transport (ENet). The host is authoritative for
## lobby state, match configuration, scores and critical match events.
## Public matchmaking is NOT implemented: no external service is required, and
## the UI says so honestly. Reconnect keeps the last address and retries.

signal connection_succeeded
signal connection_failed(reason: String)
signal server_disconnected
signal peer_list_changed
signal lobby_state_received(state: Dictionary)
signal chat_received(sender_id: int, sender_name: String, text: String, team_only: bool)
signal match_start_received(config: Dictionary)
signal net_error(message: String)

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 12
const PING_INTERVAL := 2.0

var peer: ENetMultiplayerPeer = null
var is_host := false
var connected := false
var my_id := 1
var players: Dictionary = {}
var room_code := ""
var last_address := ""
var last_port := DEFAULT_PORT
var _ping_timer := 0.0
var _rtt := 0.0


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	my_id = multiplayer.get_unique_id()


func _process(delta: float) -> void:
	if not connected:
		return
	_ping_timer += delta
	if _ping_timer >= PING_INTERVAL:
		_ping_timer = 0.0
		if is_host:
			_broadcast_presence()
		else:
			rpc_id(1, "_recv_ping", Time.get_ticks_msec())


func is_online() -> bool:
	return connected and multiplayer.multiplayer_peer != null


## ---- host / join -------------------------------------------------------

func host_game(port: int = DEFAULT_PORT) -> bool:
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		peer = null
		connection_failed.emit("server_create_failed")
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	connected = true
	my_id = multiplayer.get_unique_id()
	room_code = _make_room_code()
	players = {my_id: _make_player_entry(ProfileManager.player_name)}
	players[my_id]["host"] = true
	peer_list_changed.emit()
	return true


func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		peer = null
		connection_failed.emit("client_create_failed")
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	last_address = ip
	last_port = port
	return true


func close_connection() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	connected = false
	players = {}
	peer_list_changed.emit()


func reconnect() -> bool:
	if last_address.is_empty():
		return false
	return join_game(last_address, last_port)


func _make_room_code() -> String:
	var chars := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var code := ""
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()
	for i in 4:
		code += chars[rng.randi() % chars.length()]
	return code


func _make_player_entry(player_name: String) -> Dictionary:
	return {
		"name": player_name,
		"team": GameTypes.Team.CRIMINALS,
		"ready": false,
		"host": false,
		"ping": 0,
	}


# ---- signals ------------------------------------------------------------

func _on_connected_to_server() -> void:
	connected = true
	my_id = multiplayer.get_unique_id()
	players[my_id] = _make_player_entry(ProfileManager.player_name)
	players[my_id]["host"] = false
	connection_succeeded.emit()
	peer_list_changed.emit()
	rpc_id(1, "_recv_join_request", ProfileManager.player_name, my_id)


func _on_connection_failed() -> void:
	connected = false
	connection_failed.emit("connection_failed")


func _on_peer_connected(id: int) -> void:
	if is_host:
		players[id] = _make_player_entry("Operator")
		_assign_team(id)
		_broadcast_lobby()
	peer_list_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	if is_host:
		_broadcast_lobby()
	else:
		server_disconnected.emit()
	peer_list_changed.emit()


func _on_server_disconnected() -> void:
	connected = false
	server_disconnected.emit()


# ---- lobby --------------------------------------------------------------

func _assign_team(id: int) -> void:
	var crim := 0
	var cop := 0
	for key in players:
		if int(players[key]["team"]) == GameTypes.Team.CRIMINALS:
			crim += 1
		elif int(players[key]["team"]) == GameTypes.Team.POLICE:
			cop += 1
	players[id]["team"] = GameTypes.Team.CRIMINALS if crim <= cop else GameTypes.Team.POLICE


func set_player_team(id: int, team: int) -> void:
	if not players.has(id):
		return
	players[id]["team"] = team
	_broadcast_lobby()


func set_ready(id: int, ready: bool) -> void:
	if not players.has(id):
		return
	players[id]["ready"] = ready
	_broadcast_lobby()


func set_room_state(state: Dictionary) -> void:
	_broadcast_lobby(state)


func _broadcast_lobby(extra: Dictionary = {}) -> void:
	if not is_host:
		return
	var state := {
		"players": players,
		"room_code": room_code,
	}
	for key in extra:
		state[key] = extra[key]
	_broadcast_presence()
	for id in players.keys():
		if id != my_id:
			rpc_id(id, "_recv_lobby_state", state)


func _broadcast_presence() -> void:
	if not is_host:
		return
	var snapshot := {}
	for id in players:
		snapshot[id] = players[id].duplicate()
	rpc("_recv_presence", snapshot, Time.get_ticks_msec())


# ---- chat ---------------------------------------------------------------

func send_chat(text: String, team_only: bool = false) -> void:
	if not connected:
		return
	var sender := String(players.get(my_id, {}).get("name", ProfileManager.player_name))
	if is_host:
		chat_received.emit(my_id, sender, text, team_only)
		for id in players.keys():
			if id != my_id:
				rpc_id(id, "_recv_chat", my_id, sender, text, team_only)
	else:
		rpc_id(1, "_recv_chat", my_id, sender, text, team_only)


# ---- match start --------------------------------------------------------

func send_match_start(config: Dictionary) -> void:
	if not is_host:
		return
	for id in players.keys():
		if id != my_id:
			rpc_id(id, "_recv_match_start", config)
	match_start_received.emit(config)


# ---- RPCs ---------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _recv_join_request(player_name: String, id: int) -> void:
	if not is_host:
		return
	if players.has(id):
		players[id]["name"] = player_name
	else:
		players[id] = _make_player_entry(player_name)
		_assign_team(id)
	_broadcast_lobby()


@rpc("any_peer", "call_remote", "reliable")
func _recv_lobby_state(state: Dictionary) -> void:
	if is_host:
		return
	if not state.is_empty():
		players = state.get("players", players)
		room_code = String(state.get("room_code", room_code))
		lobby_state_received.emit(state)
		peer_list_changed.emit()


@rpc("any_peer", "call_remote", "unreliable")
func _recv_presence(snapshot: Dictionary, stamp: int) -> void:
	if is_host:
		return
	for id in snapshot:
		var key := int(id)
		if key == my_id:
			continue
		players[key] = snapshot[id]
		var rtt := int((Time.get_ticks_msec() - stamp) / 2.0)
		players[key]["ping"] = max(0, rtt)
		if players.has(my_id):
			players[my_id]["ping"] = max(0, rtt)
	peer_list_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _recv_chat(sender_id: int, sender_name: String, text: String, team_only: bool) -> void:
	chat_received.emit(sender_id, sender_name, text, team_only)


@rpc("any_peer", "call_remote", "reliable")
func _recv_match_start(config: Dictionary) -> void:
	if is_host:
		return
	match_start_received.emit(config)


@rpc("any_peer", "call_remote", "unreliable")
func _recv_ping(stamp: int) -> void:
	if is_host:
		rpc_id(multiplayer.get_remote_sender_id(), "_recv_pong", stamp)
	else:
		_rtt = Time.get_ticks_msec() - stamp


@rpc("any_peer", "call_remote", "unreliable")
func _recv_pong(stamp: int) -> void:
	_rtt = Time.get_ticks_msec() - stamp


func get_ping() -> int:
	return int(_rtt)


## Fill the free slots of both teams with bots (host side).
func apply_bot_fill(team_size: int, bots_enabled: bool) -> void:
	if not is_host:
		return
	if not bots_enabled:
		return
	var crim := 0
	var cop := 0
	for id in players:
		if int(players[id]["team"]) == GameTypes.Team.CRIMINALS:
			crim += 1
		elif int(players[id]["team"]) == GameTypes.Team.POLICE:
			cop += 1
	while crim < team_size:
		var bid := 900000 + crim + 1
		players[bid] = _make_player_entry(_bot_name(crim))
		players[bid]["team"] = GameTypes.Team.CRIMINALS
		players[bid]["bot"] = true
		players[bid]["ready"] = true
		crim += 1
	while cop < team_size:
		var bid := 910000 + cop + 1
		players[bid] = _make_player_entry(_bot_name(cop))
		players[bid]["team"] = GameTypes.Team.POLICE
		players[bid]["bot"] = true
		players[bid]["ready"] = true
		cop += 1
	_broadcast_lobby()


func _bot_name(index: int) -> String:
	var names := ["Ворон", "Кобра", "Тень", "Гром", "Лис", "Штык", "Маяк", "Ключ", "Байкал", "Резня"]
	return names[index % names.size()]
