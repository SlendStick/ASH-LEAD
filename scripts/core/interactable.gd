class_name Interactable
extends Node2D
## Base class for anything a character can use: doors, devices, loot, zones,
## medkits, civilians, hostages. All interactions are abstract game actions.

signal completed(interactable, character)
signal started(interactable, character)
signal cancelled(interactable, character)

var match_ref = null
var duration: float = 1.0
var prompt_key: String = "interact"
var enabled: bool = true
var progress: float = 0.0
var busy_by: Character = null
var label: String = ""


func _add_icon(texture_name: String, scale_factor: float = 1.0, tint: Color = Color.WHITE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/textures/%s.png" % texture_name)
	sprite.scale = Vector2.ONE * scale_factor
	sprite.modulate = tint
	add_child(sprite)
	return sprite


func get_prompt() -> String:
	return Localization.t(prompt_key)


func can_use(_character: Character) -> bool:
	return enabled


func start(character: Character) -> void:
	busy_by = character
	started.emit(self, character)


func complete(character: Character) -> void:
	busy_by = null
	completed.emit(self, character)


func cancel(_character: Character) -> void:
	busy_by = null
	cancelled.emit(self, character)


# ---------------------------------------------------------------- device

class InteractDevice extends Interactable:
	var action: String = "plant"
	var zone_index: int = 0
	var device_name: String = "device"
	var status_sprite: Sprite2D

	func _init(match_ref, pos: Vector2, device_action: String, name_key: String, time: float) -> void:
		match_ref = match_ref
		position = pos
		action = device_action
		device_name = Localization.t(name_key)
		duration = time
		prompt_key = "plant_device" if action == "plant" else "defuse_device"
		_add_icon("prop_server", 1.0)
		status_sprite = _add_icon("marker_objective", 0.8, Color(1.0, 0.35, 0.3))

	func get_prompt() -> String:
		return Localization.t(prompt_key) + " — " + device_name

	func can_use(character: Character) -> bool:
		if not enabled:
			return false
		if action == "plant":
			return character.team == GameTypes.Team.CRIMINALS and not match_ref.mode.device_planted
		return character.team == GameTypes.Team.POLICE and match_ref.mode.device_planted

	func complete(character: Character) -> void:
		super.complete(character)
		if action == "plant":
			match_ref.on_device_planted(self, character)
		else:
			match_ref.on_device_defused(self, character)


# ---------------------------------------------------------------- loot

class InteractLoot extends Interactable:
	var loot_type: String = "loot"

	func _init(match_ref, pos: Vector2, type: String) -> void:
		match_ref = match_ref
		position = pos
		loot_type = type
		duration = 1.4
		prompt_key = "take_loot"
		_add_icon("prop_crate", 0.85)

	func get_prompt() -> String:
		return Localization.t("take_loot")

	func can_use(character: Character) -> bool:
		if not enabled:
			return false
		if loot_type == "archive":
			return not character.carry_object and character.team == GameTypes.Team.CRIMINALS
		return not character.carry_object and character.team == GameTypes.Team.CRIMINALS

	func complete(character: Character) -> void:
		super.complete(character)
		match_ref.on_loot_picked(self, character)


# ---------------------------------------------------------------- zone

class InteractZone extends Interactable:
	var zone_id: int = 0
	var radius: float = 150.0
	var zone_owner: int = GameTypes.Team.NONE
	var capture_progress: float = 0.0
	var capture_team: int = GameTypes.Team.NONE
	var hold_time: float = 0.0
	var active: bool = true
	var ring: Sprite2D

	func _init(match_ref, pos: Vector2, id: int, zone_radius: float) -> void:
		match_ref = match_ref
		position = pos
		zone_id = id
		radius = zone_radius
		duration = 1.0
		prompt_key = "capture_zone"
		ring = _add_icon("fx_smoke", 1.0, Color(0.3, 0.9, 0.8, 0.3))
		ring.scale = Vector2.ONE * (radius / 64.0)

	func get_prompt() -> String:
		return Localization.t("capture_zone")

	func set_active(value: bool) -> void:
		active = value
		if ring != null:
			ring.visible = value

	func update_zone(delta: float) -> void:
		if not active:
			return
		var criminals := 0
		var police := 0
		for c in match_ref.characters:
			if not c.alive:
				continue
			if c.global_position.distance_to(global_position) > radius:
				continue
			if c.team == GameTypes.Team.CRIMINALS:
				criminals += 1
			elif c.team == GameTypes.Team.POLICE:
				police += 1
		if criminals > 0 and police == 0:
			if capture_team != GameTypes.Team.CRIMINALS:
				capture_progress -= delta * 0.5
				if capture_progress <= 0.0:
					capture_team = GameTypes.Team.CRIMINALS
					capture_progress = 0.0
			capture_progress += delta / 6.0
			if capture_progress >= 1.0:
				capture_progress = 1.0
				if zone_owner != GameTypes.Team.CRIMINALS:
					zone_owner = GameTypes.Team.CRIMINALS
					match_ref.on_zone_captured(self, GameTypes.Team.CRIMINALS)
		elif police > 0 and criminals == 0:
			capture_progress += delta / 6.0
			if capture_progress >= 1.0:
				capture_progress = 1.0
				if zone_owner != GameTypes.Team.POLICE:
					zone_owner = GameTypes.Team.POLICE
					match_ref.on_zone_captured(self, GameTypes.Team.POLICE)
		else:
			capture_progress = maxf(0.0, capture_progress - delta * 0.3)
		if zone_owner != GameTypes.Team.NONE:
			hold_time += delta


# ---------------------------------------------------------------- heal

class InteractHeal extends Interactable:
	var charges: int = 2

	func _init(match_ref, pos: Vector2, amount_charges: int) -> void:
		match_ref = match_ref
		position = pos
		charges = amount_charges
		duration = 1.6
		prompt_key = "use_medkit"
		_add_icon("icon_medkit", 0.9)

	func can_use(character: Character) -> bool:
		return enabled and charges > 0 and (character.hp < character.max_hp or character.downed)

	func complete(character: Character) -> void:
		if charges <= 0:
			return
		charges -= 1
		if character.downed:
			character.revive(character)
		else:
			character.heal(55)
		match_ref.play_sound("heal", character.global_position)
		match_ref.announce("healed", character.char_name)
		super.complete(character)
		enabled = charges > 0


# ---------------------------------------------------------------- civilian

class InteractCivilian extends Interactable:
	var civilian: Character

	func _init(match_ref, target: Character) -> void:
		match_ref = match_ref
		civilian = target
		position = target.global_position
		duration = 0.05
		prompt_key = "command_civilian"

	func get_prompt() -> String:
		return Localization.t("command_civilian") + " — " + civilian.char_name

	func can_use(character: Character) -> bool:
		return civilian.alive and character.team != GameTypes.Team.CIVILIAN

	func complete(character: Character) -> void:
		super.complete(character)
		match_ref.open_civilian_commands(character, civilian)


# ---------------------------------------------------------------- hostage

class InteractHostage extends Interactable:
	var hostage: Character
	var freed: bool = false

	func _init(match_ref, target: Character) -> void:
		match_ref = match_ref
		hostage = target
		position = target.global_position
		duration = 2.0
		prompt_key = "free_hostage"
		_add_icon("marker_objective", 0.7, Color(0.4, 0.8, 1.0))

	func get_prompt() -> String:
		return Localization.t("free_hostage")

	func can_use(character: Character) -> bool:
		return not freed and character.team == GameTypes.Team.POLICE and hostage.alive

	func complete(character: Character) -> void:
		freed = true
		enabled = false
		super.complete(character)
		match_ref.on_hostage_freed(self, character)
