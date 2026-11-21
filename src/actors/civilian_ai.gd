class_name CivilianAI
extends Node
## Civilian brain: the most human thing in the game and therefore the most
## unpredictable.
##
## Behaviour model: a small utility AI over a shared "fear" field.
##   * PERCEPTION: sees gunfire, corpses, masked criminals, police; recognizes
##     weapons vs uniform; remembers who threatened it.
##   * EMOTIONS: fear, anger, curiosity, herd instinct. Every civilian has a
##     personality profile (brave / coward / snitch / bystander / worker).
##   * ACTIONS: wander, work, flee, hide, call the police, record a video,
##     surrender, resist, follow a saviour, carry/cover hostages, scream.
##   * SOCIAL: they warn each other, form groups, block doors, panic-spread,
##     and remember faces for the whole match (witness system).

signal became_witness(civ: Actor, of_team: int)

const STATE_IDLE := "idle"
const STATE_WANDER := "wander"
const STATE_WORK := "work"
const STATE_FLEE := "flee"
const STATE_HIDE := "hide"
const STATE_CALL := "call"
const STATE_RECORD := "record"
const STATE_SURRENDER := "surrender"
const STATE_RESIST := "resist"
const STATE_FOLLOW := "follow"
const STATE_SIT := "sit"

var actor: Actor
var map: GeneratedMap
var personality := "coward"
var state := STATE_IDLE
var fear := 0.0
var anger := 0.0
var curiosity := 0.0
var target_point := Vector2.ZERO
var home_point := Vector2.ZERO
var hide_point := Vector2.ZERO
var timer := 0.0
var state_time := 0.0
var rng := RandomNumberGenerator.new()
var seen_crim := {}
var seen_police := {}
var has_called := false
var call_cooldown := 0.0
var talk_cooldown := 0.0
var recording := false
var recording_target: Actor = null
var friend: Actor = null
var witnessed: Array = []
var path: Array[Vector2] = []
var path_index := 0
var repath := 0.0
var wander_pause := 0.0
var work_spot := Vector2.ZERO
var last_scream := 0.0
var hostage_of := 0
var afraid_of: Actor = null


func setup(a: Actor, m: GeneratedMap) -> void:
	actor = a
	map = m
	rng.seed = a.a_id * 5171 + int(m.seed_value)
	home_point = a.global_position
	work_spot = a.global_position
	var rolls := rng.randf()
	if rolls < 0.3:
		personality = "coward"
	elif rolls < 0.48:
		personality = "brave"
	elif rolls < 0.64:
		personality = "snitch"
	elif rolls < 0.82:
		personality = "bystander"
	else:
		personality = "worker"
	state = STATE_WANDER
	target_point = a.global_position
	curiosity = rng.randf_range(0.2, 1.0)
	timer = rng.randf_range(0.0, 2.0)


func _physics_process(delta: float) -> void:
	if actor == null or actor.dead:
		return
	if actor.downed:
		actor.move_dir = Vector2.ZERO
		return
	timer -= delta
	state_time += delta
	call_cooldown = maxf(0.0, call_cooldown - delta)
	talk_cooldown = maxf(0.0, talk_cooldown - delta)
	repath = maxf(0.0, repath - delta)
	_perceive(delta)
	_update_emotions(delta)
	_decide(delta)
	_move(delta)
	_express(delta)


func _perceive(delta: float) -> void:
	# scan for armed actors in line of sight
	if actor.world == null or not actor.world.has_method("actors_for_team"):
		return
	for other in actor.world.call("actors_for_team", -1):
		if other == actor or other.dead:
			continue
		if other.team == Db.TEAM_CIVILIAN:
			continue
		var d := actor.global_position.distance_to(other.global_position)
		if d > 620.0:
			continue
		if other.team == Db.TEAM_CRIMINAL and seen_crim.has(other.a_id):
			continue
		if not Util.cone_contains(actor.global_position, actor.facing, other.global_position, 1.15) and d > 100.0:
			continue
		if actor.world.has_method("vision_blocked") and bool(actor.world.call("vision_blocked", actor.global_position, other.global_position)):
			continue
		if other.team == Db.TEAM_CRIMINAL:
			if not seen_crim.has(other.a_id):
				seen_crim[other.a_id] = true
				witnessed.append({"id": other.a_id, "name": other.a_name, "time": Time.get_ticks_msec() / 1000.0})
				became_witness.emit(actor, other.team)
				fear = minf(1.0, fear + 0.55)
				if talk_cooldown <= 0.0:
					talk_cooldown = 10.0
					_bark("panic")
			afraid_of = other
		else:
			seen_police[other.a_id] = true
	# corpses are terrifying
	if actor.world.has_method("visible_corpses"):
		var corpses: Array = actor.world.call("visible_corpses", actor.global_position, 420.0)
		if not corpses.is_empty():
			fear = minf(1.0, fear + delta * 2.5)
			if state in [STATE_WANDER, STATE_WORK, STATE_IDLE]:
				state = STATE_FLEE
				state_time = 0.0
				_pick_flee_point()


func hear_noise(pos: Vector2, loudness: float, kind: String) -> void:
	if actor.dead:
		return
	var d := actor.global_position.distance_to(pos)
	if d > loudness:
		return
	if kind == "gunshot":
		fear = minf(1.0, fear + 0.5)
		curiosity = minf(1.0, curiosity + 0.15)
		if personality == "snitch" and not has_called and call_cooldown <= 0.0:
			_try_call()
		elif state in [STATE_WANDER, STATE_WORK, STATE_IDLE, STATE_RECORD]:
			state = STATE_FLEE
			state_time = 0.0
			_pick_flee_point()
	elif kind in ["step", "melee", "reload"]:
		if curiosity > 0.5 and state in [STATE_WANDER, STATE_IDLE]:
			target_point = pos
			wander_pause = 0.8


func _update_emotions(delta: float) -> void:
	# fear decays slowly when nothing is happening, faster when hidden
	if state == STATE_HIDE:
		fear = maxf(0.0, fear - delta * 0.035)
	else:
		fear = maxf(0.0, fear - delta * 0.02)
	# herd instinct: fear spreads from nearby panicking civilians
	if actor.world != null and actor.world.has_method("nearby_civilians"):
		for c in actor.world.call("nearby_civilians", actor.global_position, 300.0):
			if c == actor:
				continue
			var cai = c.get("ai")
			if cai != null and "fear" in cai and float(cai.fear) > 0.6:
				fear = minf(1.0, fear + delta * 0.35)
				break
	# bravery resists panic
	if personality == "brave":
		fear *= 0.82
	elif personality == "coward":
		fear = minf(1.0, fear * 1.12)
	if actor.hp < actor.max_hp:
		fear = minf(1.0, fear + 0.4)


func _decide(delta: float) -> void:
	if state == STATE_SURRENDER and state_time < 4.0:
		return
	if fear > 0.72:
		if personality == "snitch" and not has_called and call_cooldown <= 0.0 and _has_phone_spot():
			_try_call()
			return
		if personality == "brave" and fear < 0.9 and anger > 0.3:
			state = STATE_RESIST
			return
		if state != STATE_HIDE and state != STATE_FLEE:
			if _find_hide_spot():
				state = STATE_HIDE
				state_time = 0.0
			else:
				state = STATE_FLEE
				_pick_flee_point()
		return
	if fear > 0.45:
		if personality == "snitch" and not has_called and call_cooldown <= 0.0 and _has_phone_spot():
			_try_call()
			return
		if state in [STATE_WANDER, STATE_WORK, STATE_IDLE] and rng.randf() < 0.4 and _find_hide_spot():
			state = STATE_HIDE
			state_time = 0.0
			return
	# curiosity: walk towards a fight to watch / film
	if curiosity > 0.55 and fear < 0.3 and afraid_of != null and not afraid_of.dead and state in [STATE_WANDER, STATE_IDLE]:
		if rng.randf() < 0.25 and not recording:
			state = STATE_RECORD
			state_time = 0.0
			recording = true
			recording_target = afraid_of
			_bark("record")
		return
	if state == STATE_RECORD and (afraid_of == null or afraid_of.dead or fear > 0.5):
		recording = false
		state = STATE_FLEE
		_pick_flee_point()
		return
	if state == STATE_HIDE and fear < 0.2 and state_time > 10.0:
		state = STATE_WANDER
		state_time = 0.0
	if state == STATE_FLEE and fear < 0.15 and state_time > 6.0:
		state = STATE_WANDER
		state_time = 0.0
	if state == STATE_IDLE and timer <= 0.0:
		state = STATE_WANDER
		_pick_wander_point()


func _move(delta: float) -> void:
	var desired := actor.global_position
	match state:
		STATE_FLEE:
			desired = target_point
			actor.sprinting = fear > 0.8
			actor.crouching = false
			if actor.global_position.distance_to(target_point) < 30.0:
				_pick_flee_point()
		STATE_HIDE:
			desired = hide_point
			actor.crouching = true
			actor.sprinting = false
			if actor.global_position.distance_to(hide_point) < 24.0:
				actor.move_dir = Vector2.ZERO
				actor.facing = wrapf(actor.facing + sin(state_time * 0.7) * 0.02, -PI, PI)
				# cower
				if rng.randf() < 0.01 and talk_cooldown <= 0.0:
					talk_cooldown = 8.0
					_bark("surrender")
				return
		STATE_CALL:
			desired = hide_point
			if actor.global_position.distance_to(hide_point) < 24.0:
				actor.move_dir = Vector2.ZERO
				return
		STATE_RECORD:
			if recording_target != null and is_instance_valid(recording_target) and not recording_target.dead:
				var d := actor.global_position.distance_to(recording_target.global_position)
				if d > 240.0:
					desired = recording_target.global_position + (actor.global_position - recording_target.global_position).normalized() * 200.0
				else:
					actor.move_dir = Vector2.ZERO
					actor.facing = (recording_target.global_position - actor.global_position).angle()
					return
		STATE_SURRENDER:
			actor.move_dir = Vector2.ZERO
			actor.facing = (afraid_of.global_position - actor.global_position).angle() if afraid_of != null and is_instance_valid(afraid_of) else actor.facing
			return
		STATE_RESIST:
			if afraid_of != null and is_instance_valid(afraid_of):
				var to := afraid_of.global_position - actor.global_position
				if to.length() > 34.0:
					desired = afraid_of.global_position
				else:
					actor.move_dir = Vector2.ZERO
					_shove(afraid_of)
					return
		STATE_WANDER, STATE_IDLE, STATE_WORK, STATE_FOLLOW:
			desired = target_point
			if actor.global_position.distance_to(target_point) < 24.0:
				actor.move_dir = Vector2.ZERO
				if state == STATE_WORK:
					actor.facing = wrapf(actor.facing + delta * 0.15, -PI, PI)
					if rng.randf() < 0.005:
						_bark("resist")
				else:
					wander_pause -= delta
					if wander_pause <= 0.0:
						wander_pause = rng.randf_range(1.5, 5.0)
						_pick_wander_point()
				return
	if desired != actor.global_position:
		_ensure_path(desired)
		var wp := desired
		if path.size() > 0 and path_index < path.size():
			wp = path[path_index]
			if actor.global_position.distance_to(wp) < 26.0:
				path_index += 1
				if path_index < path.size():
					wp = path[path_index]
		var dir := (wp - actor.global_position).normalized()
		actor.move_dir = dir
		actor.facing = Util.rotate_towards(actor.facing, dir.angle(), delta * 8.0)


func _express(delta: float) -> void:
	# screaming when shot or when threatened at close range
	if actor.hp < actor.max_hp and state_time - last_scream > 2.0 and fear > 0.6:
		last_scream = state_time
		Sfx.scream(actor.global_position, rng.randi_range(1, 3))


func _pick_flee_point() -> void:
	if map == null:
		target_point = actor.global_position
		return
	# run away from the threat, preferring exits and corridors
	var away := Vector2.RIGHT
	if afraid_of != null and is_instance_valid(afraid_of):
		away = (actor.global_position - afraid_of.global_position).normalized()
	var best := actor.global_position
	var best_score := -1e9
	for i in range(24):
		var ang := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(180.0, 520.0)
		var p := actor.global_position + Vector2(cos(ang), sin(ang)) * dist
		var c := map.world_to_cell(p)
		if not map.walkable(c):
			continue
		var score := Vector2(cos(ang), sin(ang)).dot(away) * 100.0
		if map.room_at_cell(c) < 0:
			score += 20.0
		var exit_p: Variant = map.points.get("extract", null)
		if exit_p != null and Vector2(exit_p).distance_to(p) < 400.0:
			score += 30.0
		if score > best_score:
			best_score = score
			best = p
	target_point = best
	path.clear()
	path_index = 0


func _find_hide_spot() -> bool:
	if map == null:
		return false
	var origin := map.world_to_cell(actor.global_position)
	var best := Vector2.ZERO
	var best_score := -1e9
	for dx in range(-9, 10):
		for dy in range(-9, 10):
			var c := origin + Vector2i(dx, dy)
			if not map.walkable(c):
				continue
			# prefer room dead ends: few exits, enclosed by walls
			var walls := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var t := map.tile_at(c + d)
				if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_CRATE:
					walls += 1
			if walls < 2:
				continue
			var p := map.cell_to_world(c)
			var score := walls * 12.0 - actor.global_position.distance_to(p) * 0.05
			if afraid_of != null and is_instance_valid(afraid_of):
				score += actor.global_position.distance_to(afraid_of.global_position) * 0.01
			if score > best_score:
				best_score = score
				best = p
	if best_score > -100.0:
		hide_point = best
		target_point = best
		path.clear()
		path_index = 0
		return true
	return false


func _pick_wander_point() -> void:
	if map == null:
		return
	var angle := rng.randf_range(0.0, TAU)
	var dist := rng.randf_range(80.0, 320.0)
	var p := home_point + Vector2(cos(angle), sin(angle)) * dist
	if map.walkable(map.world_to_cell(p)):
		target_point = p
		path.clear()
		path_index = 0
	else:
		target_point = home_point


func _ensure_path(to: Vector2) -> void:
	if path.size() > 0 and path_index < path.size() and repath > 0.0:
		return
	repath = 0.8
	path = _simple_path(actor.global_position, to)
	path_index = 0


func _simple_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if Util.los_clear(map, from, to, true):
		out.append(to)
		return out
	# greedy grid step: pick neighbour that reduces distance and is walkable
	var cur := from
	var guard := 0
	while cur.distance_to(to) > 40.0 and guard < 120:
		guard += 1
		var dir := (to - cur).normalized()
		var best := cur
		var best_d := 1e9
		for a in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2]:
			var p := cur + dir.rotated(a) * 42.0
			if map == null or not map.walkable(map.world_to_cell(p)):
				continue
			var d := p.distance_to(to)
			if d < best_d:
				best_d = d
				best = p
		if best == cur:
			break
		out.append(best)
		cur = best
		if Util.los_clear(map, cur, to, true):
			out.append(to)
			break
	return out


func _has_phone_spot() -> bool:
	return fear > 0.3


func _try_call() -> void:
	state = STATE_CALL
	hide_point = actor.global_position
	if fear > 0.5:
		_find_hide_spot()
	has_called = true
	call_cooldown = 25.0
	if talk_cooldown <= 0.0:
		talk_cooldown = 6.0
		_bark("call")
	Signals.notify.emit("Гражданский вызывает полицию...", "warning")
	if actor.world != null and actor.world.has_method("on_civilian_call"):
		actor.world.call("on_civilian_call", actor.global_position)


func _bark(kind: String) -> void:
	var lines: Array = Db.CIV_BARKS.get(kind, [])
	if lines.is_empty():
		return
	var line := str(lines[rng.randi_range(0, lines.size() - 1)])
	if rng.randf() < 0.55:
		Signals.notify.emit("%s: «%s»" % [actor.a_name, line], "info")


func _shove(other: Actor) -> void:
	if other == null or not is_instance_valid(other):
		return
	if rng.randf() < 0.3:
		other.apply_slow(1.2)
		angry_flash()
	Signals.noise_made.emit(actor.global_position, 260.0, "melee", Db.TEAM_CIVILIAN)


func angry_flash() -> void:
	anger = minf(1.0, anger + 0.5)


func surrender_to(attacker: Actor) -> void:
	afraid_of = attacker
	state = STATE_SURRENDER
	state_time = 0.0
	actor.visual.surrendering = true
	_bark("surrender")
	actor.visual.queue_redraw()


func release() -> void:
	if state == STATE_SURRENDER:
		state = STATE_HIDE
		actor.visual.surrendering = false
		actor.visual.queue_redraw()


func get_witness_report() -> Array:
	return witnessed.duplicate(true)
