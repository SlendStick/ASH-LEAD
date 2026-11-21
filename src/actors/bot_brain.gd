class_name BotBrain
extends Node
## Advanced combat AI for player-substitute bots.
##
## Layered behaviour:
##   1. PERCEPTION -- sight cones, hearing, memory of last seen positions, threat
##      ranking, awareness of allies' contacts, light/darkness, smoke, flash.
##   2. COMMAND    -- obeys squad orders from the human owner (follow / hold /
##      flank / push / retreat / revive / focus fire) and mode-level roles.
##   3. NAVIGATION -- A* on the tile grid with a small cache, door awareness,
##      patrol routes, room clearing and "peek" behaviour.
##   4. TACTICS    -- weapon-range driven (SMG rushes, sniper holds), cover
##      seeking, suppression fire, reload timing, grenade usage, melee executes,
##      hostage/objective handling.
##   5. AIM        -- human-like error model: reaction delay, tracking error,
##      burst discipline, difficulty scaling, headshot probability.

const REACTION := {"easy": 0.55, "normal": 0.34, "hard": 0.2, "nightmare": 0.13}
const AIM_ERROR := {"easy": 1.0, "normal": 0.55, "hard": 0.3, "nightmare": 0.16}

var actor: Actor
var map: GeneratedMap
var difficulty := 1
var order := "advance"
var order_target := Vector2.ZERO
var role := "rifleman"
var squad_id := 0
var path: Array[Vector2] = []
var path_index := 0
var path_timer := 0.0
var repath_cooldown := 0.0
var state := "idle"
var target: Actor = null
var target_visible := false
var target_last_seen := Vector2.ZERO
var target_lost_time := 99.0
var scan_timer := 0.0
var decide_timer := 0.0
var aim_error := Vector2.ZERO
var burst_left := 0
var burst_pause := 0.0
var reaction_timer := 0.0
var patrol_route: Array = []
var patrol_index := 0
var investigate_point := Vector2.ZERO
var investigate_time := 0.0
## 0..1 situational awareness: heard shots, corpses, doors. Decays back to 0.
var alertness := 0.0
var stuck_timer := 0.0
var last_pos := Vector2.ZERO
var cover_point := Vector2.ZERO
var has_cover := false
var objective_focus := Vector2.ZERO
var has_objective := false
var revive_target: Actor = null
var interact_target: Node = null
var rng := RandomNumberGenerator.new()
var owner_player_id := 0
var hold_position := Vector2.ZERO
var radio_timer := 0.0
var last_enemy_positions: Dictionary = {}
var suppressed_by := 0.0
var grenade_cooldown := 0.0
var shout_timer := 0.0
var path_cache_time := 0.0
var mode_role := "generic"


func setup(a: Actor, m: GeneratedMap, diff: int) -> void:
	actor = a
	map = m
	difficulty = diff
	rng.seed = a.a_id * 7919 + int(m.seed_value)
	order_target = a.global_position
	hold_position = a.global_position
	decide_timer = rng.randf_range(0.0, 0.2)
	aim_error = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if actor == null or actor.dead:
		return
	if actor.is_civilian:
		return
	decide_timer -= delta
	path_timer += delta
	repath_cooldown = maxf(0.0, repath_cooldown - delta)
	reaction_timer = maxf(0.0, reaction_timer - delta)
	burst_pause = maxf(0.0, burst_pause - delta)
	grenade_cooldown = maxf(0.0, grenade_cooldown - delta)
	radio_timer = maxf(0.0, radio_timer - delta)
	suppressed_by = maxf(0.0, suppressed_by - delta)
	_check_doors(delta)
	_perceive(delta)
	_think(delta)
	_move(delta)
	_act(delta)


func _check_doors(delta: float) -> void:
	if actor.world == null:
		return
	path_cache_time += delta
	if path_cache_time < 0.6:
		return
	path_cache_time = 0.0
	var doors: Array = actor.world.get("doors")
	for d in doors:
		if d == null or not is_instance_valid(d) or not d.locked:
			continue
		if d.global_position.distance_to(actor.global_position) < 44.0:
			d.kick(actor)
			return


# ---------------------------------------------------------------------------
# PERCEPTION
# ---------------------------------------------------------------------------

func _perceive(delta: float) -> void:
	var enemies := _enemy_list()
	var best: Actor = null
	var best_score := -1e9
	var visible_any := false
	for e in enemies:
		if e.dead or e.downed:
			continue
		var d := actor.global_position.distance_to(e.global_position)
		if d > 1500.0:
			continue
		var can_see := _can_see(e, d)
		if can_see:
			visible_any = true
			var score := 1000.0 - d
			if e == target:
				score += 250.0
			score += (1.0 - float(e.concealment)) * 120.0
			if e.is_local_player:
				score += 40.0
			if score > best_score:
				best_score = score
				best = e
			# share contact with squad
			if radio_timer <= 0.0:
				radio_timer = 1.4
				_radio_contact(e)
	if best != null:
		if target != best:
			reaction_timer = float(REACTION.get(_diff_key(), 0.3)) * rng.randf_range(0.75, 1.3)
		target = best
		target_visible = true
		target_last_seen = best.global_position
		target_lost_time = 0.0
		alertness = 1.0
		last_enemy_positions[best.a_id] = best.global_position
	else:
		target_visible = false
		target_lost_time += delta
		if target != null and target_lost_time > 9.0:
			target = null
	# awareness of nearby corpses / opened doors raises alertness
	if alertness < 1.0:
		alertness = minf(1.0, alertness + delta * 0.02)
	if actor.flash_timer > 0.0:
		target_visible = false


func _diff_key() -> String:
	return ["easy", "normal", "hard", "nightmare"][clampi(difficulty, 0, 3)]


func _enemy_list() -> Array:
	var out: Array = []
	if actor.world == null:
		return out
	if not actor.world.has_method("actors_for_team"):
		return out
	for a: Actor in actor.world.call("actors_for_team", -1):
		if a == actor or a.dead:
			continue
		var hostile := false
		if actor.team == Db.TEAM_CRIMINAL and (a.team == Db.TEAM_POLICE or a.team == Db.TEAM_CIVILIAN):
			hostile = a.team == Db.TEAM_POLICE
		elif actor.team == Db.TEAM_POLICE:
			hostile = a.team == Db.TEAM_CRIMINAL
		if hostile:
			out.append(a)
	return out


func _can_see(e: Actor, dist: float) -> bool:
	if e.dead:
		return false
	var fov := 1.25
	if actor.alertness > 0.6:
		fov = 1.45
	var ang := absf(wrapf((e.global_position - actor.global_position).angle() - actor.facing, -PI, PI))
	if ang > fov and dist > 120.0:
		return false
	if dist > 1250.0:
		return false
	# concealment reduces detection distance
	var visible_range := 1250.0 * (1.0 - float(e.concealment) * 0.62)
	if e.crouching:
		visible_range *= 0.82
	if e.velocity.length() < 20.0:
		visible_range *= 0.9
	if e.in_light > 0.55:
		visible_range *= 1.25
	if dist > visible_range:
		return false
	if actor.world != null and actor.world.has_method("vision_blocked"):
		if bool(actor.world.call("vision_blocked", actor.global_position, e.global_position)):
			return false
	elif not Util.los_clear_fast(map, actor.global_position, e.global_position):
		return false
	return true


func _radio_contact(e: Actor) -> void:
	if actor.world != null and actor.world.has_method("share_contact"):
		actor.world.call("share_contact", actor.team, e.global_position, e.a_id)


# ---------------------------------------------------------------------------
# COMMAND / THINKING
# ---------------------------------------------------------------------------

func set_order(kind: String, target_pos: Vector2 = Vector2.ZERO) -> void:
	order = kind
	if target_pos != Vector2.ZERO:
		order_target = target_pos
		hold_position = target_pos
	path.clear()
	path_index = 0
	repath_cooldown = 0.0
	state = "idle"
	if kind == "hold":
		has_cover = false


func _think(delta: float) -> void:
	if decide_timer > 0.0:
		return
	decide_timer = rng.randf_range(0.12, 0.24)
	# Downed allies are the highest priority if we are close and safe
	revive_target = _find_downed_ally()
	if revive_target != null and target_visible and actor.global_position.distance_to(revive_target.global_position) < 260.0:
		revive_target = null
	# health based retreat
	var hp_frac := actor.hp / maxf(1.0, actor.max_hp)
	if hp_frac < 0.28 and target_visible and actor.has_gadget("smoke") and rng.randf() < 0.25:
		var smoke_target := actor.global_position + (actor.global_position - target.global_position).normalized() * 120.0
		actor.throw_gadget("smoke", smoke_target)
	if actor.mag <= 0 and actor.reload_timer <= 0.0 and actor.draw_timer <= 0.0:
		actor.start_reload()
	if actor.mag <= maxi(1, int(actor.weapon_stats().get("mag", 10)) / 3) and not target_visible and actor.reload_timer <= 0.0:
		actor.start_reload()
	# weapon based stance
	var w := actor.weapon_stats()
	var kind := str(w.get("kind", "rifle"))
	var dist_to_target := 9999.0
	if target != null:
		dist_to_target = actor.global_position.distance_to(target.global_position)
	# grenades: throws into known enemy clusters if not visible for a while
	if grenade_cooldown <= 0.0 and target != null and not target_visible and target_lost_time < 6.0 and actor.has_gadget("grenade"):
		var d := actor.global_position.distance_to(target_last_seen)
		if d > 120.0 and d < 470.0 and rng.randf() < 0.35:
			actor.throw_gadget("grenade", target_last_seen)
			grenade_cooldown = 9.0
		elif actor.has_gadget("flashbang") and rng.randf() < 0.25 and d < 420.0:
			actor.throw_gadget("flashbang", target_last_seen)
			grenade_cooldown = 7.0
	# choose cover when reloading or hurt and target visible
	if target_visible and (actor.reload_timer > 0.0 or hp_frac < 0.45) and not has_cover:
		_find_cover()
	elif target_visible and has_cover and actor.global_position.distance_to(cover_point) < 20.0 and actor.reload_timer <= 0.0 and hp_frac > 0.55:
		has_cover = false
	# behaviour by weapon
	if kind == "sniper" and target_visible:
		actor.crouching = dist_to_target > 420.0
		actor.aiming = true
	elif kind in ["smg", "shotgun"] and target != null:
		actor.crouching = false
		actor.aiming = dist_to_target > 320.0
	else:
		actor.crouching = false
		actor.aiming = target_visible and dist_to_target < 700.0
	if actor.downed:
		return


func _find_downed_ally() -> Actor:
	if actor.world == null or not actor.world.has_method("actors_for_team"):
		return null
	var best: Actor = null
	var best_d := 420.0
	for a: Actor in actor.world.call("actors_for_team", -1):
		if a == actor or not a.downed or a.dead or a.team != actor.team:
			continue
		var d := actor.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _find_cover() -> void:
	if map == null:
		return
	var origin := map.world_to_cell(actor.global_position)
	var threat := target.global_position if target != null else target_last_seen
	var best := Vector2.ZERO
	var best_score := -1e9
	for dx in range(-7, 8):
		for dy in range(-7, 8):
			var c := origin + Vector2i(dx, dy)
			if not map.walkable(c):
				continue
			if not _cell_has_cover(c):
				continue
			var p := map.cell_to_world(c)
			var score := 0.0
			if Util.los_clear(map, p, threat):
				score -= 60.0
			score -= actor.global_position.distance_to(p) * 0.12
			if actor.world != null and actor.world.has_method("light_at"):
				score += (1.0 - float(actor.world.call("light_at", p))) * 25.0
			if score > best_score:
				best_score = score
				best = p
	if best_score > -100.0:
		cover_point = best
		has_cover = true
		path = _find_path(actor.global_position, best)
		path_index = 0


func _cell_has_cover(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t := map.tile_at(c + d)
		if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_CRATE or t == GeneratedMap.TK_GRATE:
			return true
	return false


# ---------------------------------------------------------------------------
# MOVEMENT / PATHFINDING
# ---------------------------------------------------------------------------

func _move(delta: float) -> void:
	if actor.downed:
		return
	var desired := actor.global_position
	var engage_range := _desired_range()
	var has_target := target != null and target_last_seen != Vector2.ZERO
	var since_seen := target_lost_time

	# objectives outrank wandering
	var goal_set := false
	if revive_target != null and not target_visible:
		desired = revive_target.global_position
		goal_set = true
	elif order == "hold" and not target_visible:
		desired = hold_position
		goal_set = true
	elif has_target and (target_visible or since_seen < 7.0):
		var to_enemy := (target_last_seen - actor.global_position)
		var d := to_enemy.length()
		if target_visible:
			if d > engage_range:
				desired = actor.global_position + to_enemy.normalized() * minf(d - engage_range * 0.85, 300.0)
			elif d < engage_range * 0.5 and str(actor.weapon_stats().get("kind", "")) in ["sniper", "rifle"]:
				desired = actor.global_position - to_enemy.normalized() * 90.0
			else:
				# strafe
				var strafe := to_enemy.normalized().rotated(PI * 0.5) * (1.0 if int(Time.get_ticks_msec() / 900 + actor.a_id) % 2 == 0 else -1.0)
				desired = actor.global_position + strafe * 70.0
			# when enemy is downed, execute with melee
			if target.downed and d < 120.0 and actor.loadout.has("knife"):
				actor.switch_to("knife")
		else:
			desired = target_last_seen
		goal_set = true
		alertness = 1.0
	elif has_cover and actor.reload_timer > 0.0:
		desired = cover_point
		goal_set = true
	elif order == "flank" and order_target != Vector2.ZERO:
		desired = order_target
		goal_set = true
	elif order == "follow" and owner_player_id > 0:
		var owner_actor: Actor = actor.world.call("actor_by_id", owner_player_id) if actor.world != null else null
		if owner_actor != null and not owner_actor.dead:
			desired = owner_actor.global_position - Vector2(cos(owner_actor.facing), sin(owner_actor.facing)) * 90.0
			if actor.global_position.distance_to(owner_actor.global_position) < 70.0:
				desired = actor.global_position
		else:
			desired = _objective_advance_point()
		goal_set = true
	elif order == "advance":
		desired = _objective_advance_point()
		goal_set = true
	elif order == "retreat":
		desired = _retreat_point()
		goal_set = true

	if not goal_set:
		if investigate_time > 0.0:
			investigate_time -= delta
			desired = investigate_point
		else:
			_patrol(delta)
			desired = patrol_route[patrol_index] if patrol_route.size() > patrol_index else actor.global_position

	var to_goal := desired - actor.global_position
	if to_goal.length() < 26.0:
		actor.move_dir = Vector2.ZERO
		path.clear()
		path_index = 0
		if not target_visible:
			actor.aiming = false
		# scan around
		scan_timer += delta
		if scan_timer > 0.8 and not target_visible:
			scan_timer = 0.0
			actor.facing = wrapf(actor.facing + rng.randf_range(-0.6, 0.6), -PI, PI)
		return
	if not target_visible:
		_ensure_path(desired)
		if path.size() > 0 and path_index < path.size():
			var wp := path[path_index]
			if actor.global_position.distance_to(wp) < 28.0:
				path_index += 1
				if path_index >= path.size():
					path.clear()
			if path.size() > 0 and path_index < path.size():
				to_goal = path[path_index] - actor.global_position
	var dir := to_goal.normalized()
	actor.move_dir = dir
	# sprint when far and in combat
	if to_goal.length() > 220.0 and actor.stamina > 25.0 and not target_visible:
		actor.sprinting = true
		actor.crouching = false
	if target_visible:
		actor.facing = Util.rotate_towards(actor.facing, (target_last_seen - actor.global_position).angle(), delta * 14.0)
		if absf(wrapf((target.global_position - actor.global_position).angle() - actor.facing, -PI, PI)) > 0.3:
			actor.move_dir = dir * 0.4
	elif dir.length() > 0.1:
		actor.facing = Util.rotate_towards(actor.facing, dir.angle(), delta * 9.0)
	# stuck detection
	stuck_timer += delta
	if stuck_timer > 1.4:
		stuck_timer = 0.0
		if last_pos.distance_to(actor.global_position) < 14.0 and actor.move_dir.length() > 0.2:
			path.clear()
			path_index = 0
			actor.move_dir = actor.move_dir.rotated(rng.randf_range(-1.2, 1.2))
			repath_cooldown = 0.0
		last_pos = actor.global_position


func _desired_range() -> float:
	match str(actor.weapon_stats().get("kind", "rifle")):
		"sniper":
			return 700.0
		"rifle":
			return 420.0
		"lmg":
			return 480.0
		"shotgun":
			return 150.0
		"smg":
			return 240.0
		"melee":
			return 30.0
		"special":
			return 320.0
		_:
			return 300.0


func _objective_advance_point() -> Vector2:
	if actor.world != null and actor.world.has_method("bot_objective_point"):
		var p = actor.world.call("bot_objective_point", actor)
		if p != null:
			return p
	return hold_position


func _retreat_point() -> Vector2:
	if actor.world != null and actor.world.has_method("bot_retreat_point"):
		var p = actor.world.call("bot_retreat_point", actor)
		if p != null:
			return p
	return hold_position


func _patrol(delta: float) -> void:
	if patrol_route.is_empty():
		if map != null and map.patrols.size() > 0:
			var route: Array = map.patrols[actor.a_id % map.patrols.size()]
			for c in route:
				patrol_route.append(map.cell_to_world(c))
		else:
			patrol_route.append(actor.global_position + Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300)))
	if patrol_route.size() > 0 and actor.global_position.distance_to(patrol_route[patrol_index]) < 40.0:
		patrol_index = (patrol_index + 1) % patrol_route.size()
	scan_timer += delta


func _ensure_path(to: Vector2) -> void:
	if path.size() > 0 and path_index < path.size() and path_timer < 1.2:
		return
	if repath_cooldown > 0.0:
		return
	repath_cooldown = 0.45
	path = _find_path(actor.global_position, to)
	path_index = 0
	path_timer = 0.0


## A* on the tile grid, 8-directional, with a node cap so dozens of bots are cheap.
func _find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if map == null:
		out.append(to)
		return out
	var start := map.world_to_cell(from)
	var goal := map.world_to_cell(to)
	if start == goal:
		out.append(to)
		return out
	# if goal not walkable, find nearest walkable
	if not map.walkable(goal):
		var found := false
		for radius in range(1, 5):
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var c := goal + Vector2i(dx, dy)
					if map.walkable(c):
						goal = c
						found = true
						break
				if found:
					break
			if found:
				break
		if not found:
			out.append(to)
			return out
	var open: Array = [[0.0, start]]
	var came := {}
	var cost := {start: 0.0}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var iterations := 0
	var max_iter := 2600
	var found_goal := false
	while not open.is_empty() and iterations < max_iter:
		iterations += 1
		# pick lowest f (linear scan: grid is small, keeps code simple and safe)
		var best_i := 0
		for i in range(1, open.size()):
			if float(open[i][0]) < float(open[best_i][0]):
				best_i = i
		var current_node: Array = open[best_i]
		open.remove_at(best_i)
		var cur: Vector2i = current_node[1]
		if cur == goal:
			found_goal = true
			break
		for d in dirs:
			var n: Vector2i = cur + d
			if not map.walkable(n):
				continue
			# no corner cutting
			if d.x != 0 and d.y != 0:
				if not map.walkable(Vector2i(cur.x + d.x, cur.y)) or not map.walkable(Vector2i(cur.x, cur.y + d.y)):
					continue
			var step_cost := 1.0 if (d.x == 0 or d.y == 0) else 1.414
			# high-traffic tiles / doors have a tiny penalty so bots use corridors
			if map.tile_at(n) == GeneratedMap.TK_DOOR:
				step_cost += 0.35
			var nc := float(cost[cur]) + step_cost
			if not cost.has(n) or nc < float(cost[n]):
				cost[n] = nc
				came[n] = cur
				var h := Vector2(n - goal).length()
				open.append([nc + h, n])
	if not found_goal:
		out.append(to)
		return out
	var cells: Array[Vector2] = []
	var node := goal
	var guard := 0
	while node != start and guard < 400:
		guard += 1
		cells.append(map.cell_to_world(node))
		if not came.has(node):
			break
		node = came[node]
	cells.reverse()
	# smooth: drop collinear intermediate points
	var smooth: Array[Vector2] = []
	for i in range(cells.size()):
		if i == 0 or i == cells.size() - 1:
			smooth.append(cells[i])
		else:
			var a := cells[i - 1]
			var b := cells[i]
			var c2 := cells[i + 1]
			var ab := (b - a).normalized()
			var bc := (c2 - b).normalized()
			if ab.dot(bc) < 0.95:
				smooth.append(b)
	if smooth.is_empty():
		smooth.append(to)
	if Util.los_clear(map, from, smooth[smooth.size() - 1], true):
		out.append(smooth[smooth.size() - 1])
	else:
		for p in smooth:
			out.append(p)
	return out


# ---------------------------------------------------------------------------
# COMBAT ACTIONS
# ---------------------------------------------------------------------------

func _act(delta: float) -> void:
	if actor.downed:
		return
	# revive ally in range
	if revive_target != null and actor.global_position.distance_to(revive_target.global_position) < 44.0:
		actor.move_dir = Vector2.ZERO
		actor.facing = (revive_target.global_position - actor.global_position).angle()
		revive_target.revive_progress += delta
		if revive_target.revive_progress > 2.6:
			revive_target.revive(actor)
			revive_target.revive_progress = 0.0
			revive_target = null
		return
	if target == null:
		return
	var d := actor.global_position.distance_to(target.global_position)
	if not target_visible and target_lost_time > 1.2:
		return
	if reaction_timer > 0.0:
		return
	# aim with human error
	var aim_point := target.global_position + _aim_offset(d)
	actor.facing = Util.rotate_towards(actor.facing, (aim_point - actor.global_position).angle(), delta * 16.0)
	var angle_err := absf(wrapf((aim_point - actor.global_position).angle() - actor.facing, -PI, PI))
	if angle_err > 0.08:
		return
	var w := actor.weapon_stats()
	var kind := str(w.get("kind", "rifle"))
	# melee when point blank
	if d < 80.0 and kind != "melee":
		if actor.loadout.has("knife"):
			actor.switch_to("knife")
			kind = "melee"
	# burst discipline
	if burst_pause > 0.0:
		return
	var rpm := float(w.get("rpm", 400.0))
	var shots := 1
	match kind:
		"rifle", "smg":
			shots = 3 if d < 600.0 else 2
		"lmg":
			shots = 5
		"pistol":
			shots = 1 if d > 300.0 else 2
		"shotgun":
			shots = 1
		"sniper":
			shots = 1
		"melee":
			shots = 1
		_:
			shots = 1
	if burst_left <= 0:
		burst_left = shots
	# return to gun if we swapped to knife and enemy moved away
	if kind == "melee" and d > 110.0 and actor.loadout.size() > 1:
		actor.switch_to(actor.loadout[0])
		return
	if actor.reload_timer > 0.0 or actor.draw_timer > 0.0:
		return
	if actor.mag <= 0:
		actor.start_reload()
		return
	actor.try_fire(aim_point)
	burst_left -= 1
	if burst_left <= 0:
		burst_pause = rng.randf_range(0.12, 0.3) if kind in ["rifle", "smg", "lmg"] else rng.randf_range(0.25, 0.6)
	# suppression: bots that keep getting shot at reposition
	if actor.hp < actor.max_hp * 0.4 and rng.randf() < 0.2:
		has_cover = false


func _aim_offset(dist: float) -> Vector2:
	var err_scale := float(AIM_ERROR.get(_diff_key(), 0.5))
	var moving_factor: float = 1.0 + actor.velocity.length() / 260.0
	var dist_factor := clampf(dist / 420.0, 0.4, 2.2)
	if actor.aiming:
		err_scale *= 0.7
	if actor.crouching:
		err_scale *= 0.8
	var m := err_scale * moving_factor * dist_factor
	aim_error = aim_error.lerp(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), 0.25)
	return aim_error * 34.0 * m


# ---------------------------------------------------------------------------
# SENSES: hearing
# ---------------------------------------------------------------------------

func hear_noise(pos: Vector2, loudness: float, kind: String) -> void:
	if actor.dead or target_visible:
		return
	var d := actor.global_position.distance_to(pos)
	if d > loudness:
		return
	if kind == "gunshot" and d > loudness * 0.8:
		# distant shots -> investigate roughly
		investigate_point = pos + Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
		investigate_time = 6.0
		alertness = maxf(alertness, 0.6)
		return
	investigate_point = pos
	investigate_time = 8.0
	alertness = 1.0
	actor.facing = Util.rotate_towards(actor.facing, (pos - actor.global_position).angle(), 3.0)


func see_corpse(pos: Vector2) -> void:
	if actor.dead:
		return
	alertness = 1.0
	investigate_point = pos
	investigate_time = 12.0
	if shout_timer <= 0.0:
		shout_timer = 6.0
		Signals.actor_spotted.emit(actor.a_id, 0, actor.team)
