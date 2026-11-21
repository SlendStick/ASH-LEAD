class_name LanDiscovery
extends Node
## LAN server browser.
##
## A host broadcasts a tiny UDP beacon (hostname, mode, map, players, port) once
## a second on port 47801; every client listens and keeps a list of servers that
## answered in the last 4 seconds. This is the "browse LAN" half of the online
## screen -- no master server, no accounts, works on a local network or a VPN.
##
## The class is transport-agnostic: it only discovers endpoints. Joining still
## goes through NetLink.join_lan().

const BEACON_PORT := 47801
const BEACON_INTERVAL := 1.0
const SERVER_TTL := 4.0

var udp: PacketPeerUDP
var broadcasting := false
var listening := false
var servers: Array[Dictionary] = []
var _accum := 0.0
var _beacon := {}


func _ready() -> void:
	set_process(false)


## Host side: start announcing this match on the LAN.
func start_broadcast(info: Dictionary) -> void:
	stop_all()
	_beacon = info.duplicate(true)
	udp = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	var err := udp.set_dest_address("255.255.255.255", BEACON_PORT)
	if err != OK:
		broadcasting = false
		return
	broadcasting = true
	_accum = BEACON_INTERVAL
	set_process(true)


## Client side: listen for beacons.
func start_listen() -> void:
	if listening:
		return
	if udp != null:
		udp.close()
	udp = PacketPeerUDP.new()
	var err := udp.bind(BEACON_PORT, "*")
	if err != OK:
		listening = false
		return
	listening = true
	set_process(true)


func update_beacon(key: String, value: Variant) -> void:
	_beacon[key] = value


## Keeps the LAN beacon in sync with the lobby (called by whoever owns the host).
func update_from_lobby(lobby: Array, mode_name: String, map_name: String) -> void:
	_beacon["players"] = lobby.size()
	_beacon["mode"] = mode_name
	_beacon["map"] = map_name
	_beacon["host"] = NetLink.display_name
	_beacon["port"] = NetLink.DEFAULT_PORT


func stop_all() -> void:
	if udp != null:
		udp.close()
		udp = null
	broadcasting = false
	listening = false
	servers.clear()
	set_process(false)


func _process(delta: float) -> void:
	_accum += delta
	if broadcasting and udp != null and _accum >= BEACON_INTERVAL:
		_accum = 0.0
		var payload := JSON.stringify(_beacon).to_utf8_buffer()
		udp.put_packet(payload)
	if listening and udp != null:
		while udp.get_available_packet_count() > 0:
			var packet := udp.get_packet()
			var ip := udp.get_packet_ip()
			var parsed = JSON.parse_string(packet.get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = parsed
			entry["ip"] = ip
			entry["seen"] = Time.get_ticks_msec() / 1000.0
			_merge_server(entry)
	# expire old servers
	var now := Time.get_ticks_msec() / 1000.0
	var alive: Array[Dictionary] = []
	for s in servers:
		if now - float(s.get("seen", 0.0)) < SERVER_TTL:
			alive.append(s)
	servers = alive


func _merge_server(entry: Dictionary) -> void:
	for i in range(servers.size()):
		if str(servers[i].get("ip", "")) == str(entry.get("ip", "")) and int(servers[i].get("port", 0)) == int(entry.get("port", 0)):
			servers[i] = entry
			return
	servers.append(entry)
