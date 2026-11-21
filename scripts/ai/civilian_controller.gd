class_name CivilianController
extends Node
## Civilian NPC: routine, suspicion, search, flee, hide, help and panic.
## Panic spreads between people with a delay; memory is limited and stressful.

const SUSPICION_DECAY := 0.12
const PANIC_RADIUS := 420.0
const REPORT_DELAY := 4.0

var character: Character
var match_ref: Match = null
var state: int = GameTypes.NPCState.ROUTINE
var home_pos: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.INF
var wander_timer := 0.0
var suspicion := 0.0
var panic := 0.0
var alert: int = GameTypes.AlertState.CALM
var confidence := 0.4
var memory := {
	"danger_pos": Vector2.INF,
	"danger_dir": Vector2.RIGHT,
	"danger_room": "",
	"blocked": [],
	"helped": [],
}
var command_type := "none"
var command_from: Character = null
var follow_target: Character = null
var report_timer := 0.0
var heal_target: Character = null
var scream_timer := 0.0
var calm_timer := 0.0
var _saw_threat: bool = false


func _init(character_ref: Character, match: Match, conf: float = 0.4) -> void:
	character = character_ref
	match_ref = match
	confidence = conf


func _process(delta: float) -> void:
	if character == null or not character.alive:
		return
	_senses(delta)
	match state:
		GameTypes.NPCState.ROUTINE:
			_process_routine(delta)
		GameTypes.NPCState.SUSPICIOUS:
			_process_suspicious(delta)
		GameTypes.NPCState.SEARCH:
			_process_search(delta)
		GameTypes.NPCState.FLEE:
			_process_flee(delta)
		GameTypes.NPCState.HIDE:
			_process_hide(delta)
		GameTypes.NPCState.PANIC:
			_process_panic(delta)
		GameTypes.NPCState.HELP:
			_process_help(delta)
		GameTypes.NPCState.FOLLOW:
			_process_follow(delta)
		GameTypes.NPCState.STAY:
			character.move_input = Vector2.ZERO
	suspicion = maxf(0.0, suspicion - SUSPICION_DECAY * delta)
	panic = maxf(0.0, panic - 0.25 * delta)


# ---- senses ---------------------------------------------------------------

func _senses(delta: float) -> void:
	var seen_threat := false
	for other in match_ref.characters:
		if other == character or not other.alive:
			continue
		var dist := character.global_position.distance_to(other.global_position)
		if dist > 480.0:
			continue
		if not match_ref.map_data.has_los(character.global_position, other.global_position):
			continue
		if other.team == GameTypes.Team.CRIMINALS or other.team == GameTypes.Team.POLICE:
			if other.get_weapon() != null and other.get_weapon().ammo_in_mag > 0:
				seen_threat = true
				memory["danger_pos"] = other.global_position
				memory["danger_dir"] = (other.global_position - character.global_position).normalized()
				if dist < 240.0 and confidence < 0.8:
					panic = minf(1.0, panic + 1.6 * delta * (1.2 - confidence))
		elif other.downed or (not other.alive and other.sprite != null):
			if dist < 260.0:
				seen_threat = true
				panic = minf(1.0, panic + 1.2 * delta)
				memory["danger_pos"] = other.global_position
	# Hearing.
	var heard: Array = match_ref.noise.query(character.global_position, 0.9)
	for e in heard:
		var conf: float = float(e["confidence"])
		if conf > 0.2:
			suspicion = minf(1.0, suspicion + conf * delta * 1.5)
			memory["danger_pos"] = e["pos"] + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			memory["danger_dir"] = e["direction"]
	# Resonance raises general alertness.
	alert = match_ref.resonance.level()
	_saw_threat = seen_threat
	if seen_threat and confidence >= 0.8 and state == GameTypes.NPCState.ROUTINE:
		# Brave civilians may try to help rather than flee.
		_try_help()
	# State transitions.
	if panic > 0.6 and state != GameTypes.NPCState.PANIC and state != GameTypes.NPCState.FLEE:
		_enter_panic()
	elif suspicion > 0.85 and state == GameTypes.NPCState.ROUTINE:
		state = GameTypes.NPCState.SUSPICIOUS
		wander_timer = 0.0
	elif suspicion < 0.15 and state == GameTypes.NPCState.SUSPICIOUS:
		state = GameTypes.NPCState.ROUTINE
	# Report to the authorities when it is safe enough.
	if seen_threat and match_ref.resonance.level() >= GameTypes.AlertState.SEARCH:
		report_timer += delta
		if report_timer >= REPORT_DELAY:
			report_timer = 0.0
			match_ref.on_civilian_report(character, memory["danger_pos"])
	# Scream while panicking.
	scream_timer -= delta
	if state == GameTypes.NPCState.PANIC and scream_timer <= 0.0:
		scream_timer = 2.5
		match_ref.resonance.add_panic(character.global_position)


func on_panic_nearby(pos: Vector2) -> void:
	if state == GameTypes.NPCState.DEAD:
		return
	if character.global_position.distance_to(pos) > PANIC_RADIUS:
		return
	panic = minf(1.0, panic + 0.55)
	suspicion = minf(1.0, suspicion + 0.4)
	if state == GameTypes.NPCState.ROUTINE or state == GameTypes.NPCState.SUSPICIOUS:
		_enter_panic()


func _enter_panic() -> void:
	state = GameTypes.NPCState.PANIC
	wander_timer = randf_range(1.2, 2.4)
	match_ref.resonance.add_panic(character.global_position)


# ---- states ---------------------------------------------------------------

func _process_routine(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.5, 6.0)
		if randf() < 0.7:
			wander_target = match_ref.map_data.random_walkable_near(
				match_ref.map_data.world_to_tile(home_pos), 5, RandomNumberGenerator.new())
		else:
			wander_target = Vector2.INF
	if wander_target.x >= 0:
		_move_to(wander_target, 0.7)
		if character.global_position.distance_to(wander_target) < 40.0:
			wander_target = Vector2.INF
	else:
		character.move_input = Vector2.ZERO


func _process_suspicious(delta: float) -> void:
	wander_timer += delta
	var target: Vector2 = memory["danger_pos"]
	if target == Vector2.INF:
		state = GameTypes.NPCState.ROUTINE
		return
	var dist := character.global_position.distance_to(target)
	if dist > 190.0:
		_move_to(target, 0.75)
	else:
		character.move_input = Vector2.ZERO
		character.aim_target = character.global_position + memory["danger_dir"] * 200.0
		character.want_crouch = true
	if wander_timer > 6.0 and not _saw_threat:
		state = GameTypes.NPCState.ROUTINE
		character.want_crouch = false


func _process_search(delta: float) -> void:
	_process_suspicious(delta)


func _process_flee(delta: float) -> void:
	var exit_pos := _nearest_evac()
	if exit_pos == Vector2.INF:
		exit_pos = home_pos
	_move_to(exit_pos, 1.4)
	if character.global_position.distance_to(exit_pos) < 90.0:
		match_ref.on_civilian_evacuated(character)
		state = GameTypes.NPCState.HIDE
		character.visible = false
		character.collision_layer = 0
		character.collision_mask = 0


func _process_hide(delta: float) -> void:
	character.move_input = Vector2.ZERO
	character.want_crouch = true
	calm_timer += delta
	if calm_timer > 9.0 and panic < 0.2 and not _saw_threat:
		calm_timer = 0.0
		state = GameTypes.NPCState.ROUTINE
		character.want_crouch = false


func _process_panic(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.7, 1.4)
		var random_dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		wander_target = character.global_position + random_dir * randf_range(120.0, 260.0)
	_move_to(wander_target, 1.5)
	if panic < 0.25 and not _saw_threat:
		state = GameTypes.NPCState.FLEE


func _process_help(delta: float) -> void:
	if heal_target == null or not heal_target.alive or not heal_target.downed:
		heal_target = _find_injured()
		if heal_target == null:
			state = GameTypes.NPCState.ROUTINE
			return
	var dist := character.global_position.distance_to(heal_target.global_position)
	if dist > 70.0:
		_move_to(heal_target.global_position, 1.1)
	else:
		character.move_input = Vector2.ZERO
		# Civilians help each other directly: revive the downed, treat the hurt.
		if heal_target.downed:
			heal_target.revive(character)
			match_ref.announce("healed", heal_target.char_name)
			state = GameTypes.NPCState.ROUTINE
			heal_target = null
		elif heal_target.hp < heal_target.max_hp:
			heal_target.heal(40)
			match_ref.announce("healed", heal_target.char_name)
			state = GameTypes.NPCState.ROUTINE
			heal_target = null


func _process_follow(delta: float) -> void:
	if follow_target == null or not follow_target.alive:
		state = GameTypes.NPCState.ROUTINE
		return
	var dist := character.global_position.distance_to(follow_target.global_position)
	if dist > 110.0:
		_move_to(follow_target.global_position, 1.15)
	else:
		character.move_input = Vector2.ZERO
		character.aim_target = follow_target.aim_target


# ---- commands -------------------------------------------------------------

func command(cmd: String, from: Character) -> void:
	command_type = cmd
	command_from = from
	match cmd:
		"stay":
			state = GameTypes.NPCState.STAY
			follow_target = null
		"follow":
			state = GameTypes.NPCState.FOLLOW
			follow_target = from
		"exit":
			state = GameTypes.NPCState.FLEE
			calm_timer = 0.0
		"calm":
			panic = maxf(0.0, panic - 0.6)
			suspicion = maxf(0.0, suspicion - 0.5)
			if panic < 0.3:
				state = GameTypes.NPCState.ROUTINE
		"help":
			heal_target = _find_injured()
			if heal_target != null:
				state = GameTypes.NPCState.HELP
	# Negotiators calm people better.
	if from != null and from.role == GameTypes.Role.NEGOTIATOR:
		panic = maxf(0.0, panic - 0.4)
		suspicion = maxf(0.0, suspicion - 0.3)
	match_ref.announce("civ_ack", character.char_name)


# ---- helpers --------------------------------------------------------------

func _move_to(pos: Vector2, speed: float) -> void:
	character.speed_scale = speed
	character.stealth_mode = false
	var to := pos - character.global_position
	if to.length() < 24.0:
		character.move_input = Vector2.ZERO
		return
	var dir := to.normalized()
	# Avoid remembered danger when possible.
	if memory["danger_pos"] != Vector2.INF and character.global_position.distance_to(memory["danger_pos"]) < 260.0:
		var away: Vector2 = (character.global_position - memory["danger_pos"]).normalized()
		dir = (dir + away * 0.8).normalized()
	character.move_input = dir
	character.aim_target = character.global_position + dir * 180.0


func _nearest_evac() -> Vector2:
	var best := Vector2.INF
	var best_d := 1e9
	for e in match_ref.map_data.evac:
		var d: float = character.global_position.distance_to(e["pos"])
		if d < best_d:
			best_d = d
			best = e["pos"]
	return best


func _find_injured() -> Character:
	for other in match_ref.characters:
		if other == character or other.team != GameTypes.Team.CIVILIAN:
			continue
		if other.downed or other.hp < other.max_hp * 0.5:
			return other
	return null


func _try_help() -> void:
	if randf() < confidence * 0.7:
		heal_target = _find_injured()
		if heal_target != null:
			state = GameTypes.NPCState.HELP
