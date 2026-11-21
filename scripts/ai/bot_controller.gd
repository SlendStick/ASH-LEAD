class_name BotController
extends Node
## Team bot AI. Uses the same perception rules as players: line of sight,
## light, noise, reaction time and imperfect accuracy. Follows orders from
## any human player on its team.

const REPATH_INTERVAL := 1.2
const STUCK_DISTANCE := 18.0

var character: Character
var match_ref = null
var difficulty: int = 1
var active: bool = true

var state: String = "idle"
var order_type: int = GameTypes.OrderType.FREE
var order_target: Vector2 = Vector2.INF
var order_character: Character = null
var order_interactable = null

var path: Array = []
var path_index: int = 0
var repath_timer := 0.0
var target: Character = null
var last_known: Vector2 = Vector2.INF
var reaction_timer := 0.0
var burst_left := 0
var burst_cooldown := 0.0
var investigate_pos: Vector2 = Vector2.INF
var investigate_timer := 0.0
var stuck_timer := 0.0
var last_position := Vector2.ZERO
var cover_point: Vector2 = Vector2.INF
var guard_dir: Vector2 = Vector2.RIGHT
var _order_ack_cd := 0.0


func _init(character_ref: Character, match_ref, diff: int = 1) -> void:
	character = character_ref
	match_ref = match_ref
	difficulty = diff


func _ready() -> void:
	last_position = character.global_position


func _process(delta: float) -> void:
	if not active or character == null or not character.alive:
		return
	_order_ack_cd = maxf(0.0, _order_ack_cd - delta)
	_perceive(delta)
	match state:
		"combat":
			_process_combat(delta)
		"search":
			_process_search(delta)
		_:
			_process_order(delta)
	_follow_path(delta)
	_update_stuck(delta)


# ---- perception -----------------------------------------------------------

func _perceive(delta: float) -> void:
	# Validate current target.
	if target != null and (not target.alive or not Perception.can_see(character, target, match_ref.map_view)):
		if target != null and target.alive:
			last_known = target.global_position
			investigate_pos = last_known
			investigate_timer = 8.0
		target = null
	# Acquire a new target.
	if target == null:
		reaction_timer -= delta
		var best: Character = null
		var best_vis := 0.0
		for other in match_ref.characters:
			if other.team == character.team or not other.alive:
				continue
			if other.team == GameTypes.Team.CIVILIAN and character.team == GameTypes.Team.CRIMINALS:
				# Criminals avoid drawing attention to civilians unless attacked.
				if not _threatened_by(other):
					continue
			var vis: float = Perception.visibility(character, other, match_ref.map_view)
			if vis > 0.28 and vis > best_vis:
				best_vis = vis
				best = other
		if best != null and reaction_timer <= 0.0:
			target = best
			last_known = best.global_position
			reaction_timer = _reaction_time()
			state = "combat"
			burst_left = 0
			burst_cooldown = 0.0
			match_ref.on_bot_spotted(character, best)
		elif best != null:
			# Seen but still reacting: face the threat.
			character.aim_target = best.global_position
	# Hearing.
	if target == null and investigate_timer <= 0.0:
		var heard: Array = match_ref.noise.query(character.global_position, 1.0)
		var loudest := {}
		var best_conf := 0.0
		for e in heard:
			if float(e["confidence"]) > best_conf:
				best_conf = float(e["confidence"])
				loudest = e
		if not loudest.is_empty() and best_conf > 0.25:
			investigate_pos = loudest["pos"] + Vector2(randf_range(-70, 70), randf_range(-70, 70))
			investigate_timer = 6.0
			if state != "search":
				state = "search"
				match_ref.announce("bot_investigate", character.char_name)


func _threatened_by(other: Character) -> bool:
	return other.team == GameTypes.Team.POLICE


func _reaction_time() -> float:
	match difficulty:
		0:
			return randf_range(0.65, 0.95)
		1:
			return randf_range(0.4, 0.6)
		_:
			return randf_range(0.22, 0.38)


# ---- combat ---------------------------------------------------------------

func _process_combat(delta: float) -> void:
	if target == null or not target.alive:
		target = null
		state = "search"
		investigate_pos = last_known
		investigate_timer = 8.0
		return
	character.aim_target = target.global_position + target.velocity * 0.06
	var dist := character.global_position.distance_to(target.global_position)
	var weapon := character.get_weapon()
	if weapon == null:
		return
	# Reload when safe.
	if weapon.ammo_in_mag <= int(weapon.data.get("mag", 1)) * 0.25 and not weapon.reloading:
		weapon.start_reload(1.0)
		match_ref.play_sound("reload_start", character.global_position)
	# Movement: keep preferred range, strafe.
	var preferred := weapon.range * 0.55
	var move := Vector2.ZERO
	if dist > preferred * 1.25:
		move = (target.global_position - character.global_position).normalized()
	elif dist < preferred * 0.5:
		move = -(target.global_position - character.global_position).normalized()
	else:
		var perp := (target.global_position - character.global_position).normalized().rotated(PI * 0.5)
		move = perp * (1.0 if (character.player_id % 2 == 0) else -1.0)
	character.move_input = move
	character.want_crouch = dist > preferred
	# Firing.
	burst_cooldown = maxf(0.0, burst_cooldown - delta)
	if burst_left > 0:
		if _can_hit(target):
			character.want_fire = true
			burst_left -= 1
			if burst_left <= 0:
				burst_cooldown = randf_range(0.35, 0.8) * (1.6 - 0.3 * difficulty)
		else:
			burst_left = 0
	elif burst_cooldown <= 0.0 and dist < weapon.range * 0.95 and _can_hit(target):
		burst_left = 3 + (difficulty * 2) + (character.player_id % 3)
	character.want_fire = burst_left > 0 and _can_hit(target)
	# Apply bot accuracy penalty by nudging aim.
	if character.want_fire:
		var error_deg := 1.2 + 2.2 * (1.0 - 0.3 * difficulty)
		var err := deg_to_rad(error_deg) * randf_range(-1.0, 1.0)
		character.aim_target = character.aim_target.rotated(err)


func _can_hit(target: Character) -> bool:
	if reaction_timer > 0.0:
		return false
	if not match_ref.map_data.has_los(character.global_position, target.global_position):
		return false
	var dist := character.global_position.distance_to(target.global_position)
	var weapon := character.get_weapon()
	if weapon == null:
		return false
	if dist > weapon.range:
		return false
	# Reaction: only fire when roughly facing the target.
	var dir := (target.global_position - character.global_position).normalized()
	return absf(U.angle_diff(character.aim_dir.angle(), dir.angle())) < 0.5


# ---- search ---------------------------------------------------------------

func _process_search(delta: float) -> void:
	investigate_timer -= delta
	if investigate_timer <= 0.0:
		investigate_timer = 0.0
		state = "hold"
		return
	if investigate_pos != Vector2.INF:
		_move_to(investigate_pos)
		character.aim_target = investigate_pos
		if character.global_position.distance_to(investigate_pos) < 60.0:
			# Look around.
			character.move_input = Vector2.ZERO
			character.aim_target = character.global_position + guard_dir * 200.0
			guard_dir = guard_dir.rotated(0.8)


# ---- orders ----------------------------------------------------------------

func set_order(type: int, data: Dictionary = {}) -> void:
	order_type = type
	order_target = data.get("pos", Vector2.INF)
	order_character = data.get("character", null)
	order_interactable = data.get("interactable", null)
	investigate_timer = 0.0
	target = null
	if type == GameTypes.OrderType.CANCEL:
		order_type = GameTypes.OrderType.FREE
	state = "order"
	_ack("order_ack")
	match_ref.announce_order(character, type)


func _process_order(delta: float) -> void:
	match order_type:
		GameTypes.OrderType.FOLLOW:
			_follow_character(order_character, 90.0)
		GameTypes.OrderType.HOLD:
			character.move_input = Vector2.ZERO
			character.want_crouch = false
		GameTypes.OrderType.MOVE:
			if order_target != Vector2.INF:
				_move_to(order_target)
		GameTypes.OrderType.COVER:
			character.move_input = Vector2.ZERO
			if order_target != Vector2.INF:
				character.aim_target = order_target
			character.want_crouch = true
		GameTypes.OrderType.GATHER:
			_follow_character(order_character, 70.0)
		GameTypes.OrderType.INTERACT:
			if order_interactable != null:
				_move_to(order_interactable.global_position)
				if character.global_position.distance_to(order_interactable.global_position) < Character.INTERACT_RANGE * 0.8:
					character.want_interact = true
		GameTypes.OrderType.HELP:
			_follow_character(order_character, 80.0)
			if order_character != null and order_character.downed:
				character.want_interact = true
		GameTypes.OrderType.ESCORT:
			_follow_character(order_character, 120.0)
		GameTypes.OrderType.STEALTH:
			character.stealth_mode = true
			character.want_crouch = true
			if order_target != Vector2.INF:
				_move_to(order_target)
		GameTypes.OrderType.FREE:
			character.stealth_mode = false
			character.move_input = Vector2.ZERO
			if match_ref.objective_position() != Vector2.INF:
				character.aim_target = character.global_position + (match_ref.objective_position() - character.global_position).normalized() * 200.0


func _follow_character(other: Character, standoff: float) -> void:
	if other == null or not other.alive:
		return
	character.stealth_mode = false
	var dist := character.global_position.distance_to(other.global_position)
	if dist > standoff * 1.6:
		_move_to(other.global_position)
		character.want_crouch = false
	else:
		character.move_input = Vector2.ZERO
		character.aim_target = other.aim_target


# ---- movement --------------------------------------------------------------

func _move_to(pos: Vector2) -> void:
	repath_timer -= get_process_delta_time()
	if path.is_empty() or path_index >= path.size() or repath_timer <= 0.0:
		path = match_ref.map_data.find_path(character.global_position, pos)
		path_index = 0
		repath_timer = REPATH_INTERVAL + randf() * 0.5
	if path.is_empty():
		character.move_input = Vector2.ZERO
		return
	var waypoint: Vector2 = path[path_index]
	var to_waypoint := waypoint - character.global_position
	if to_waypoint.length() < 26.0:
		path_index += 1
		if path_index >= path.size():
			character.move_input = Vector2.ZERO
			return
		waypoint = path[path_index]
		to_waypoint = waypoint - character.global_position
	character.move_input = to_waypoint.normalized()
	character.aim_target = character.global_position + to_waypoint.normalized() * 220.0


func _follow_path(delta: float) -> void:
	if path.is_empty() or path_index >= path.size():
		return


func _update_stuck(delta: float) -> void:
	if character.move_input.length() > 0.1:
		if character.global_position.distance_to(last_position) < STUCK_DISTANCE * delta:
			stuck_timer += delta
			if stuck_timer > 0.8:
				path = []
				repath_timer = 0.0
				# Sidestep.
				character.move_input = character.move_input.rotated(PI * 0.5)
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
	last_position = character.global_position


func _ack(sound_name: String) -> void:
	if _order_ack_cd > 0.0:
		return
	_order_ack_cd = 1.5
	match_ref.play_sound(sound_name, character.global_position, -12.0)


func has_line_of_sight_to(pos: Vector2) -> bool:
	return match_ref.map_data.has_los(character.global_position, pos)
