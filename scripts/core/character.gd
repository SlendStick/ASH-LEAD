class_name Character
extends CharacterBody2D
## Shared character: movement, health, weapons, interactions, noise and
## perception hooks. Player and bot controllers drive it through the
## `input_*` fields.

signal died(character: Character, killer: Character)
signal downed(character: Character)
signal revived(character: Character)
signal health_changed(hp: int, max_hp: int)
signal weapon_changed(weapon: Weapon)
signal ammo_changed(weapon: Weapon)
signal interact_started(interactable)
signal interact_finished(interactable)
signal interact_progress(progress: float)

const WALK_SPEED := 155.0
const SPRINT_SPEED := 235.0
const CROUCH_SPEED := 78.0
const ACCEL := 1400.0
const STAMINA_DRAIN := 26.0
const STAMINA_REGEN := 16.0
const INTERACT_RANGE := 110.0

var match_ref: Match = null
var char_name: String = "Оператор"
var team: int = GameTypes.Team.NONE
var role: int = GameTypes.Role.OBSERVER
var player_id: int = 0
var is_bot: bool = false
var controlled: bool = false
var controller = null

var max_hp: int = 100
var hp: int = 100
var armor: int = 0
var max_armor: int = 0
var alive: bool = true
var downed: bool = false
var bleed_out: float = 0.0

var move_input: Vector2 = Vector2.ZERO
var want_sprint: bool = false
var want_crouch: bool = false
var aim_target: Vector2 = Vector2.RIGHT
var want_fire: bool = false
var want_alt: bool = false
var want_interact: bool = false
var want_reload: bool = false
var want_gadget: bool = false
var want_melee: bool = false
var want_slot: int = -1

var move_dir: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.RIGHT
var crouching: bool = false
var sprinting: bool = false
var stamina: float = 100.0
var suppression: float = 0.0
var noise_level: float = 0.0
var carry_object: bool = false
var stealth_mode: bool = false
var speed_scale: float = 1.0
var aiming: bool = false

var weapons: Array = []
var weapon_index: int = 0
var gadgets: Dictionary = {}
var gadget_index: int = 0
var gadget_cooldown: float = 0.0
var medkits: int = 0
var ammo_boxes: int = 0

var sprite: Sprite2D
var marker: Sprite2D
var health_bar: Sprite2D
var health_bar_bg: Sprite2D
var aim_light: Light2D
var white_texture: Texture2D
var _step_timer := 0.0
var _noise_timer := 0.0
var _suppress_decay := 4.0
var _interact_target = null
var _interact_progress := 0.0
var _interact_active: bool = false
var _bleed_enabled: bool = false


func _ready() -> void:
	white_texture = _make_white_texture()
	collision_layer = 2 | 4
	collision_mask = 1 | 2 | 4 | 8
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape_node.shape = circle
	add_child(shape_node)
	_build_visuals()


func setup(config: Dictionary) -> void:
	char_name = String(config.get("name", char_name))
	team = int(config.get("team", GameTypes.Team.NONE))
	role = int(config.get("role", GameTypes.Role.OBSERVER))
	is_bot = bool(config.get("is_bot", false))
	player_id = int(config.get("player_id", 0))
	controlled = bool(config.get("controlled", false))
	if config.has("max_hp"):
		max_hp = int(config["max_hp"])
	hp = max_hp
	var loadout: Dictionary = config.get("loadout", {})
	_apply_loadout(loadout)
	_apply_team_visual()
	_apply_armor(loadout.get("armor", 0))
	health_changed.emit(hp, max_hp)
	weapon_changed.emit(get_weapon())


func _apply_loadout(loadout: Dictionary) -> void:
	weapons = []
	for key in ["primary", "secondary"]:
		var wid := String(loadout.get(key, ""))
		if wid.is_empty():
			continue
		var wdata := Data.weapon(wid)
		if wdata.is_empty():
			continue
		var weapon := Weapon.new(wdata)
		weapons.append(weapon)
	if weapons.is_empty():
		weapons.append(Weapon.new(Data.weapon("p9")))
	var melee_data := Data.weapon("knife")
	weapons.append(Weapon.new(melee_data))
	weapon_index = 0
	gadgets = {}
	var gadget_id := String(loadout.get("gadget", ""))
	if not gadget_id.is_empty():
		gadgets[gadget_id] = 1
	medkits = int(loadout.get("medkits", 0))
	ammo_boxes = int(loadout.get("ammo_boxes", 0))


func _apply_armor(value: int) -> void:
	match int(value):
		1:
			max_armor = 50
		2:
			max_armor = 100
		_:
			max_armor = 0
	armor = max_armor
	if max_armor > 0 and sprite != null:
		sprite.scale = Vector2(1.06, 1.06)


func _apply_team_visual() -> void:
	if sprite == null:
		return
	var prefix := "char_crim_"
	match team:
		GameTypes.Team.CRIMINALS:
			prefix = "char_crim_"
		GameTypes.Team.POLICE:
			prefix = "char_cop_"
		GameTypes.Team.CIVILIAN:
			prefix = "char_civ_"
	var index := 1 + (abs(char_name.hash()) % 4)
	var tex_name := prefix
	match team:
		GameTypes.Team.POLICE:
			var cops := ["patrol", "response", "medic", "neg", "inv"]
			tex_name = prefix + cops[role % cops.size()]
		GameTypes.Team.CIVILIAN:
			tex_name = prefix + str(index)
		_:
			tex_name = prefix + str(index)
	sprite.texture = load("res://assets/textures/%s.png" % tex_name)
	if marker != null:
		var marker_tex := "marker_criminals"
		match team:
			GameTypes.Team.POLICE:
				marker_tex = "marker_police"
			GameTypes.Team.CIVILIAN:
				marker_tex = "marker_civilian"
		marker.texture = load("res://assets/textures/%s.png" % marker_tex)


func _build_visuals() -> void:
	marker = Sprite2D.new()
	marker.texture = load("res://assets/textures/marker_criminals.png")
	marker.position = Vector2(0, 20)
	marker.scale = Vector2(0.42, 0.42)
	marker.z_index = -1
	add_child(marker)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/textures/char_crim_1.png")
	add_child(sprite)
	health_bar_bg = Sprite2D.new()
	health_bar_bg.texture = white_texture
	health_bar_bg.position = Vector2(0, -34)
	health_bar_bg.scale = Vector2(44, 5)
	health_bar_bg.modulate = Color(0, 0, 0, 0.6)
	add_child(health_bar_bg)
	health_bar = Sprite2D.new()
	health_bar.texture = white_texture
	health_bar.position = Vector2(-22, -34)
	health_bar.scale = Vector2(44, 5)
	health_bar.modulate = Color(0.25, 0.9, 0.55)
	add_child(health_bar)
	aim_light = Light2D.new()
	aim_light.texture = _make_cone_texture(256)
	aim_light.energy = 1.5
	aim_light.color = Color(0.75, 0.85, 1.0, 0.85)
	aim_light.texture_scale = 2.4
	aim_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(aim_light)


# ---- weapons ---------------------------------------------------------------

func get_weapon() -> Weapon:
	if weapons.is_empty():
		return null
	return weapons[clampi(weapon_index, 0, weapons.size() - 1)]


func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == weapon_index:
		return
	weapon_index = index
	get_weapon().cancel_reload()
	_apply_ammo_state()
	weapon_changed.emit(get_weapon())


func cycle_weapon(dir: int) -> void:
	switch_weapon(wrapi(weapon_index + dir, 0, weapons.size()))


func _apply_ammo_state() -> void:
	ammo_changed.emit(get_weapon())


# ---- per-frame -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if downed:
		_process_downed(delta)
		return
	_update_stamina(delta)
	_update_movement(delta)
	_update_aim()
	_update_weapon_state(delta)
	_update_noise(delta)
	_update_interaction(delta)
	suppression = maxf(0.0, suppression - delta * _suppress_decay)
	_update_health_bar()


func _update_stamina(delta: float) -> void:
	var moving := move_input.length() > 0.1
	sprinting = want_sprint and moving and stamina > 1.0 and not crouching and not stealth_mode
	crouching = want_crouch or stealth_mode
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(100.0, stamina + STAMINA_REGEN * delta * (0.4 if moving else 1.0))


func _update_movement(delta: float) -> void:
	move_dir = move_input.limit_length(1.0)
	if carry_object:
		move_dir *= 0.72
	var speed := WALK_SPEED * speed_scale
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if aiming:
		speed *= 0.72
	if max_armor >= 100:
		speed *= 0.88
	elif max_armor >= 50:
		speed *= 0.94
	var target_velocity := move_dir * speed
	var accel := ACCEL if move_dir.length() > 0.05 else ACCEL * 1.4
	velocity = velocity.move_toward(target_velocity, accel * delta)
	move_and_slide()
	if match_ref != null:
		match_ref.open_doors_near(self)


func _update_aim() -> void:
	var to_target := aim_target - global_position
	if to_target.length() > 4.0:
		aim_dir = to_target.normalized()
	if sprite != null:
		sprite.rotation = aim_dir.angle()
	if aim_light != null:
		aim_light.rotation = aim_dir.angle()


func _update_weapon_state(delta: float) -> void:
	var weapon := get_weapon()
	if weapon == null:
		return
	weapon.update(delta)
	if want_slot >= 0 and want_slot < weapons.size():
		switch_weapon(want_slot)
		want_slot = -1
	if want_melee:
		want_melee = false
		switch_weapon(weapons.size() - 1)
	if want_reload:
		want_reload = false
		if weapon.start_reload(1.0):
			match_ref.play_sound("reload_start", global_position)
	if want_gadget:
		want_gadget = false
		_use_gadget()
	if weapon.is_melee:
		if want_fire:
			want_fire = false
			_melee_attack()
		return
	if want_fire and (weapon.is_auto or not _fired_this_press):
		if weapon.can_fire():
			_fire()
		elif weapon.ammo_in_mag == 0 and not weapon.reloading:
			match_ref.play_sound("dryfire", global_position)
			weapon.start_reload(1.0)
			match_ref.play_sound("reload_start", global_position)
	_fired_this_press = want_fire


var _fired_this_press := false


func _fire() -> void:
	var weapon := get_weapon()
	if weapon == null or not weapon.can_fire():
		return
	weapon.consume()
	_apply_ammo_state()
	var spread_deg := weapon.effective_spread(self)
	var base_angle := aim_dir.angle()
	for i in weapon.pellets:
		var spread := deg_to_rad(spread_deg) * randf_range(-1.0, 1.0)
		var dir := Vector2.RIGHT.rotated(base_angle + spread)
		match_ref.fire_bullet(self, global_position + dir * 22.0, dir, weapon)
	match_ref.spawn_flash(global_position + aim_dir * 26.0, aim_dir)
	match_ref.play_sound("shoot_" + weapon.weapon_class, global_position, -4.0, randf_range(0.94, 1.06))
	match_ref.noise.add_noise(global_position, 1.0, 700.0 * weapon.noise, self)
	match_ref.resonance.add_noise_event(global_position, weapon.noise)
	match_ref.spawn_shell(global_position + aim_dir.rotated(PI * 0.5) * 14.0)
	suppression = minf(1.0, suppression + 0.12)
	match_ref.add_camera_kick(aim_dir, 0.35 * float(weapon.data.get("recoil", 1.0)))


func _melee_attack() -> void:
	var weapon := get_weapon()
	if weapon == null or not weapon.can_fire():
		return
	weapon.consume()
	_apply_ammo_state()
	match_ref.play_sound("shoot_melee", global_position)
	var hit := match_ref.melee_hit(self, aim_dir, 78.0, weapon.damage)
	if hit != null:
		match_ref.spawn_blood(hit.global_position, aim_dir, 1)


func _use_gadget() -> void:
	if gadgets.is_empty() or gadget_cooldown > 0.0:
		return
	var gadget_id: String = String(gadgets.keys()[gadget_index % gadgets.size()])
	gadget_cooldown = 6.0
	match_ref.use_gadget(self, String(gadget_id))


# ---- damage ----------------------------------------------------------------

func apply_damage(amount: float, from: Character, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if not alive or downed:
		return
	var dmg := amount
	if armor > 0:
		var absorbed := dmg * (0.45 if max_armor >= 100 else 0.3)
		var armor_dmg := minf(armor, absorbed)
		armor -= int(armor_dmg)
		dmg -= armor_dmg
	hp -= int(dmg)
	suppression = minf(1.0, suppression + 0.35)
	health_changed.emit(hp, max_hp)
	match_ref.spawn_blood(global_position, hit_dir, 2)
	match_ref.play_sound("hit_flesh", global_position, -6.0)
	if hp <= 0:
		_on_hp_zero(from)
	elif from != null and from.team != team:
		match_ref.add_suppression_around(global_position, 260.0)


func _on_hp_zero(from: Character) -> void:
	if match_ref.config.get("downed_enabled", false) and not downed and not is_bot:
		downed = true
		hp = 0
		bleed_out = 30.0
		collision_layer = 8
		velocity = Vector2.ZERO
		downed.emit(self)
		match_ref.on_character_downed(self, from)
		return
	_die(from)


func _die(from: Character) -> void:
	alive = false
	hp = 0
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if sprite != null:
		sprite.modulate = Color(0.35, 0.3, 0.32, 0.9)
		sprite.rotation = aim_dir.angle() + PI * 0.5
	if marker != null:
		marker.visible = false
	if health_bar != null:
		health_bar.visible = false
		health_bar_bg.visible = false
	died.emit(self, from)
	if match_ref != null:
		match_ref.on_character_died(self, from)


func revive(by: Character) -> void:
	if not downed:
		return
	downed = false
	hp = int(max_hp * 0.45)
	bleed_out = 0.0
	collision_layer = 2 | 4
	alive = true
	if sprite != null:
		sprite.modulate = Color.WHITE
	revived.emit(self)
	health_changed.emit(hp, max_hp)


func heal(amount: int) -> void:
	if not alive:
		return
	hp = mini(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func _process_downed(delta: float) -> void:
	bleed_out -= delta
	_update_health_bar()
	if bleed_out <= 0.0:
		_die(null)


func add_suppression(value: float) -> void:
	suppression = minf(1.0, suppression + value)


func _update_health_bar() -> void:
	if health_bar == null:
		return
	var frac := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	health_bar.scale.x = 44.0 * frac
	health_bar.position.x = -22.0 + 22.0 * frac
	if downed:
		health_bar.modulate = Color(0.95, 0.25, 0.2)
	elif frac < 0.35:
		health_bar.modulate = Color(0.9, 0.3, 0.3)
	else:
		health_bar.modulate = Color(0.25, 0.9, 0.55)


# ---- noise -----------------------------------------------------------------

func _update_noise(delta: float) -> void:
	var speed_ratio := move_dir.length()
	if speed_ratio < 0.05:
		noise_level = 0.0
		return
	var loudness := 0.25
	if sprinting:
		loudness = 0.8
	elif crouching:
		loudness = 0.1
	_noise_timer += delta * (1.6 if sprinting else 1.0)
	if _noise_timer >= 0.34:
		_noise_timer = 0.0
		noise_level = loudness
		if match_ref != null:
			match_ref.noise.add_noise(global_position, loudness, 320.0 * loudness + 60.0, self)
			match_ref.play_footstep(self, crouching, sprinting)


# ---- interaction -----------------------------------------------------------

func _update_interaction(delta: float) -> void:
	if match_ref == null:
		return
	var target = match_ref.find_interactable(self, INTERACT_RANGE)
	if target != _interact_target:
		if _interact_active:
			_cancel_interact()
		_interact_target = target
		if target != null and controlled:
			match_ref.hint(target.get_prompt())
	if want_interact and _interact_target != null and not _interact_active:
		_start_interact(_interact_target)
	if not want_interact and _interact_active:
		_cancel_interact()
	if _interact_active and _interact_target != null:
		_interact_progress += delta / maxf(0.1, _interact_target.duration)
		if _interact_progress >= 1.0:
			var finished = _interact_target
			_cancel_interact()
			finished.complete(self)
			interact_finished.emit(finished)
			match_ref.hint("")
		else:
			interact_progress.emit(_interact_progress)


func _start_interact(target) -> void:
	_interact_active = true
	_interact_progress = 0.0
	target.start(self)
	interact_started.emit(target)


func _cancel_interact() -> void:
	if _interact_target != null:
		_interact_target.cancel(self)
	_interact_active = false
	_interact_progress = 0.0


func get_interact_progress() -> float:
	return _interact_progress


func get_interact_target():
	return _interact_target


# ---- helpers ---------------------------------------------------------------

func _make_white_texture() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _make_cone_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var local := Vector2(x - half, y - half)
			var d := local.length() / half
			var ang := absf(U.angle_diff(0.0, local.angle()))
			var cone := clampf(1.0 - ang / 0.75, 0.0, 1.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * cone
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func distance_to(other: Character) -> float:
	return global_position.distance_to(other.global_position)


func is_enemy_of(other: Character) -> bool:
	if other == null:
		return false
	if match_ref != null and bool(match_ref.config.get("ffa", false)):
		return other.player_id != player_id
	return other.team != team and other.team != GameTypes.Team.CIVILIAN and team != GameTypes.Team.CIVILIAN


func swap_team(new_team: int) -> void:
	team = new_team
	_apply_team_visual()
