class_name NetCodec
extends RefCounted
## Wire format for host-authoritative matches.
##
## Everything sent over the wire is a compact Dictionary of primitive values so
## it survives ENet, WebSocket relays and JSON with no extra dependencies. The
## codec only *encodes*: the host packs actor state, the client unpacks it into
## the local actor array. Keep both directions in one file so the contract can
## never drift.


## Quantise a float to 2 decimals so snapshots stay small.
static func q(v: float) -> float:
	return roundf(v * 100.0) / 100.0


## One actor + one weapon state -> a 20 Hz snapshot row.
static func actor_row(a) -> Dictionary:
	if a == null:
		return {}
	var w: Dictionary = a.weapon_stats()
	return {
		"id": a.a_id,
		"t": a.team,
		"peer": int(a.get_meta("peer", 0)),
		"n": a.a_name,
		"x": q(a.global_position.x),
		"y": q(a.global_position.y),
		"f": q(a.facing),
		"hp": int(a.hp),
		"ar": int(a.armor),
		"w": a.current_weapon,
		"mg": a.mag,
		"rs": a.reserve,
		"dn": 1 if a.downed else 0,
		"dd": 1 if a.dead else 0,
		"cr": 1 if a.crouching else 0,
		"sp": 1 if a.sprinting else 0,
		"am": 1 if a.aiming else 0,
		"rl": 1 if a.reload_timer > 0.0 else 0,
		"out": a.skin_outfit,
		"out2": str(a.visual.colors[0]) if a.visual != null and a.visual.colors.size() > 0 else "",
		"vn": w.get("name", ""),
	}


## The whole world -> one snapshot packet. Sent by the host at SNAPSHOT_HZ.
static func build_snapshot(world: Node) -> Dictionary:
	if world == null:
		return {}
	var rows: Array = []
	var actors: Array = world.get("actors")
	for a in actors:
		if a == null or not is_instance_valid(a):
			continue
		rows.append(actor_row(a))
	var doors_arr: Array = []
	var doors: Array = world.get("doors")
	for d in doors:
		if d == null or not is_instance_valid(d):
			continue
		doors_arr.append({"id": d.door_id, "o": 1 if d.open else 0, "l": 1 if d.locked else 0, "s": q(d.swing)})
	var obj: Array = []
	var mode_node: Node = world.get("mode")
	if mode_node != null and mode_node.has_method("net_state"):
		obj = mode_node.call("net_state")
	var sc: Dictionary = world.get("team_score")
	return {
		"tick": int(float(world.get("elapsed")) * 20.0),
		"el": q(float(world.get("elapsed"))),
		"sc": [int(sc.get(0, 0)), int(sc.get(1, 0))],
		"al": int(world.get("alarm_level")),
		"pa": 1 if bool(world.get("police_arrived")) else 0,
		"pt": q(float(world.get("police_arrive_timer"))),
		"a": rows,
		"d": doors_arr,
		"o": obj,
	}


## Rows that actually changed compared with the previous snapshot. The host keeps
## the previous packet around and only pays bandwidth for movement/damage.
static func diff(prev: Dictionary, cur: Dictionary) -> Dictionary:
	if prev.is_empty():
		return cur
	var out: Dictionary = cur.duplicate(false)
	var pa: Array = prev.get("a", [])
	var ca: Array = cur.get("a", [])
	var changed: Array = []
	# match rows by actor id, not by array position: dead actors drop out of the
	# snapshot and would otherwise shift every later row
	var old_by_id := {}
	for old_row in pa:
		old_by_id[int(old_row.get("id", -1))] = old_row
	for row in ca:
		var old: Dictionary = old_by_id.get(int(row.get("id", -1)), {})
		if old.is_empty():
			changed.append(row)
			continue
		var same := true
		for k in ["id", "x", "y", "f", "hp", "ar", "mg", "rs", "dn", "dd", "cr", "sp", "am", "rl", "w"]:
			if old.get(k) != row.get(k):
				same = false
				break
		if not same:
			changed.append(row)
	out["a"] = changed
	out["full"] = false
	if prev.get("d") == cur.get("d") and prev.get("o") == cur.get("o"):
		out.erase("d")
		out.erase("o")
	return out


## Client input -> an intent packet for the host (unreliable, <= 8 fields).
static func input_packet(p, seq: int) -> Dictionary:
	if p == null:
		return {}
	return {
		"seq": seq,
		"mx": q(p.move_dir.x),
		"my": q(p.move_dir.y),
		"fa": q(p.facing),
		"aim": 1 if p.aiming else 0,
		"sp": 1 if p.sprinting else 0,
		"cr": 1 if p.crouching else 0,
		"fir": 1 if Input.is_action_pressed("fire") else 0,
		"it": 1 if Input.is_action_pressed("interact") else 0,
	}


## Order packet: which squad command the local player just gave.
static func order_packet(kind: String, pos: Vector2) -> Dictionary:
	return {"k": kind, "x": q(pos.x), "y": q(pos.y)}


## Client-side interpolation: apply first, then blend towards the latest packet.
static func apply_actor(a, row: Dictionary) -> void:
	if a == null or row.is_empty():
		return
	var target := Vector2(float(row.get("x", a.global_position.x)), float(row.get("y", a.global_position.y)))
	# small correction only -- big jumps are teleports (respawn/possession)
	if a.global_position.distance_to(target) < 260.0:
		a.global_position = a.global_position.lerp(target, 0.45)
	else:
		a.global_position = target
	a.facing = float(row.get("f", a.facing))
	a.hp = float(row.get("hp", a.hp))
	a.armor = float(row.get("ar", a.armor))
	a.mag = int(row.get("mg", a.mag))
	a.reserve = int(row.get("rs", a.reserve))
	a.downed = bool(int(row.get("dn", 0)))
	a.dead = bool(int(row.get("dd", 0)))
	a.crouching = bool(int(row.get("cr", 0)))
	a.sprinting = bool(int(row.get("sp", 0)))
	a.aiming = bool(int(row.get("am", 0)))
	var wid := str(row.get("w", a.current_weapon))
	if wid != a.current_weapon:
		a.current_weapon = wid
