class_name NetSession
extends RefCounted
## Match-time network session. Owns everything that has to happen *during* a
## round on top of the lobby:
##
##   HOST   -- builds snapshots at 20 Hz, sends the diff, applies client inputs
##             and orders, streams the map seed so clients rebuild the level.
##   CLIENT -- sends its input/orders up, applies snapshots to the actors it got
##             from the host's roster, and never simulates AI locally.
##
## The class is deliberately tiny in surface area: MatchWorld calls `tick()` once
## per frame and pushes inputs through `send_input()`. When the transport is
## LOCAL the whole object is a no-op, so a solo match pays nothing.

const SEND_HZ := 20.0
const INPUT_HZ := 30.0
const FULL_RESEND_EVERY := 8.0   # seconds between full (non-diff) snapshots

var world: Node = null
var is_active := false
var is_host := false
var my_peer := 1
var send_accum := 0.0
var input_accum := 0.0
var full_accum := 0.0
var input_seq := 0
var last_snapshot: Dictionary = {}
var last_prev: Dictionary = {}
var frames_sent := 0
var frames_recv := 0
var bytes_estimate := 0
var last_rtt_ms := 0
var _roster_sent := false


func setup(world_node: Node) -> void:
	world = world_node
	var t := str(NetLink.transport)
	is_active = t != NetLink.TRANSPORT_LOCAL
	is_host = bool(NetLink.is_host)
	my_peer = NetLink.my_peer_id()
	NetLink.snapshot_received.connect(_on_snapshot)
	NetLink.match_hook = self
	NetLink.connection_failed.connect(_on_fail)
	if is_active and is_host:
		_send_roster.call_deferred()


func _on_fail(reason: String) -> void:
	if world != null and world.has_method("on_net_failure"):
		world.call("on_net_failure", reason)


# ---------------------------------------------------------------------------
# HOST
# ---------------------------------------------------------------------------

## The client needs the exact same map: send the seed + mode + roster once.
func _send_roster() -> void:
	if not is_active or not is_host or world == null:
		return
	var m: GeneratedMap = world.get("map")
	var rows: Array = []
	for a in world.get("actors"):
		if a == null or not is_instance_valid(a) or a.is_civilian:
			continue
		rows.append({
			"id": a.a_id, "n": a.a_name, "t": a.team, "bot": a.is_bot,
			"out": a.skin_outfit, "peer": int(a.get_meta("peer", 1)),
		})
	var payload := {
		"seed": int(world.get("cfg").get("seed", 0)),
		"theme": m.theme_id,
		"mode": str(world.get("cfg").get("mode", "heist")),
		"roster": rows,
		"host_peer": my_peer,
	}
	NetLink.rpc_any("net_roster", payload)
	_roster_sent = true


## Called by NetLink.net_roster on a client.
func _client_roster(payload: Dictionary) -> void:
	if world != null and world.has_method("on_net_roster"):
		world.call("on_net_roster", payload)


## Called by NetLink.net_input on the host.
func _host_input(peer: int, packet: Dictionary) -> void:
	if world == null or not is_host:
		return
	var a = world.call("actor_for_peer", peer) if world.has_method("actor_for_peer") else null
	if a == null or not is_instance_valid(a) or a.dead:
		return
	world.call("apply_net_input", a, packet)


## Called by NetLink.net_order on the host.
func _host_order(peer: int, packet: Dictionary) -> void:
	if world == null or not is_host:
		return
	var a = world.call("actor_for_peer", peer) if world.has_method("actor_for_peer") else null
	if a == null:
		return
	world.call("apply_net_order", a, packet)


# ---------------------------------------------------------------------------
# CLIENT
# ---------------------------------------------------------------------------

func _client_tick(delta: float) -> void:
	input_accum += delta
	if input_accum < 1.0 / INPUT_HZ:
		return
	input_accum = 0.0
	var p = world.get("local_actor") if world != null else null
	if p == null or p.dead:
		return
	input_seq += 1
	NetLink.rpc_any("net_input", NetCodec.input_packet(p, input_seq))


func _on_snapshot(data: Dictionary) -> void:
	if is_host or world == null:
		return
	frames_recv += 1
	world.call("apply_snapshot", data)


func send_order(kind: String, pos: Vector2) -> void:
	if not is_active or is_host:
		return
	NetLink.rpc_any("net_order", NetCodec.order_packet(kind, pos))


# ---------------------------------------------------------------------------
# TICK
# ---------------------------------------------------------------------------

func tick(delta: float) -> void:
	if not is_active or world == null:
		return
	if is_host:
		_host_tick(delta)
	else:
		_client_tick(delta)


func stats_line() -> String:
	if not is_active:
		return "ЛОКАЛЬНО"
	var role := "ХОСТ" if is_host else "КЛИЕНТ"
	return "%s  %d Гц  %.1f КБ  %d мс" % [role, frames_sent if is_host else frames_recv, float(bytes_estimate) / 1024.0, NetLink.latency_ms]
