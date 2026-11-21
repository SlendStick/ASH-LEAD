class_name Match
extends Node2D
## Match root: builds the map, spawns characters and bots, runs phases,
## resolves combat, objectives, deaths and results.

signal match_finished(results: Dictionary)
signal phase_changed(phase: int)
signal feed_message(text: String)
signal hint_changed(text: String)
signal pause_requested
signal death_screen_requested(info: Dictionary)
signal order_wheel_requested
signal scoreboard_requested
signal map_requested

const PREP_TIME := 6.0
const POST_TIME := 4.0
const RESPAWN_TIME := 3.0
const MAX_DECALS := 70

var config: Dictionary = {}
var map_data: MapData
var map_view: MapView
var characters: Array = []
var players: Array = []
var interactables: Array = []
var local_player: Character = null
var local_controller: PlayerController = null
var local_team: int = GameTypes.Team.CRIMINALS
var camera: Camera2D
var listener: AudioListener2D
var noise: NoiseManager
var fog: FogOfWar
var resonance: CityResonance
var mode: GameMode
var hud = null
var replay: ReplayRecorder = null

var phase: int = GameTypes.GamePhase.LOBBY
var phase_time: float = 0.0
var elapsed: float = 0.0
var paused: bool = false
var finished: bool = false
var smoke_zones: Array = []
var effects: Array = []
var decals: Array = []
var decal_root: Node2D
var effect_root: Node2D
var tracer_root: Node2D
var respawn_queue: Array = []
var _camera_shake: float = 0.0
var _camera_offset: Vector2 = Vector2.ZERO
var _mouse_world: Vector2 = Vector2.ZERO
var _feed: Array = []
var _civ_wrappers: Dictionary = {}
var _hint_text: String = ""
var civilian_total: int = 0
var stats: Dictionary = {}
var deferred_team: int = -1
var police_arrived: bool = true
var ui_blocking: bool = false


func _ready() -> void:
	if not has_node("World"):
		var world := Node2D.new()
		world.name = "World"
		add_child(world)


func start_match(match_config: Dictionary) -> void:
	config = match_config.duplicate(true)
	if not config.has("players") or config["players"].is_empty():
		config["players"] = _build_default_players()
	var map_id := String(config.get("map", "clinic"))
	var seed_value := int(config.get("seed", 1))
	map_data = MapGenerator.generate(map_id, seed_value)
	_build_world()
	_spawn_characters()
	_spawn_civilians()
	mode = GameMode.create_mode(String(config.get("mode", "plant")), self)
	if mode != null:
		add_child(mode)
		mode.setup()
		resonance.reset()
		fog.reset()
	replay = load("res://scripts/match/replay_recorder.gd").new()
	replay.start(self)
	set_phase(GameTypes.GamePhase.PREP)
	AudioManager.play_ambient("ambient_rain" if Data.map(map_id).get("outside", false) else "ambient_room")
	AudioManager.play_music("music_match")
	feed(Localization.t("match_start"))
	if hud != null:
		hud.on_match_started(self)


# ----------------------------------------------------------------------------

func _build_world() -> void:
	var world := get_node("World")
	for child in world.get_children():
		child.queue_free()
	map_view = MapView.new()
	world.add_child(map_view)
	map_view.setup(map_data)
	decal_root = Node2D.new()
	decal_root.name = "Decals"
	world.add_child(decal_root)
	effect_root = Node2D.new()
	effect_root.name = "Effects"
	world.add_child(effect_root)
	tracer_root = Node2D.new()
	tracer_root.name = "Tracers"
	world.add_child(tracer_root)
	noise = NoiseManager.new()
	add_child(noise)
	fog = FogOfWar.new()
	add_child(fog)
	resonance = CityResonance.new()
	add_child(resonance)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * float(SettingsManager.get_setting("camera_zoom"))
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map_data.width * MapData.TILE_SIZE)
	camera.limit_bottom = int(map_data.height * MapData.TILE_SIZE)
	world.add_child(camera)
	camera.make_current()
	listener = AudioListener2D.new()
	listener.listen_to_audio_bus = 1
	camera.add_child(listener)


func _build_default_players() -> Array:
	var team_size := int(config.get("team_size", 5))
	var out: Array = []
	var local_entry := {
		"id": 1,
		"name": ProfileManager.player_name,
		"team": GameTypes.Team.CRIMINALS,
		"is_bot": false,
		"controlled": true,
		"loadout": _default_loadout(GameTypes.Team.CRIMINALS),
		"role": GameTypes.Role.OBSERVER,
	}
	out.append(local_entry)
	var difficulty := int(config.get("bot_difficulty", 1))
	for i in team_size - 1:
		out.append(_bot_entry(GameTypes.Team.CRIMINALS, i, difficulty))
	for i in team_size:
		out.append(_bot_entry(GameTypes.Team.POLICE, i, difficulty))
	return out


func _bot_entry(team: int, index: int, difficulty: int) -> Dictionary:
	var names := ["Ворон", "Кобра", "Тень", "Гром", "Лис", "Штык", "Маяк", "Ключ"]
	return {
		"id": 900 + team * 100 + index,
		"name": names[index % names.size()] + "-" + str(team),
		"team": team,
		"is_bot": true,
		"controlled": false,
		"loadout": _default_loadout(team),
		"role": wrapi(index, 0, 6),
		"difficulty": difficulty,
	}


func _default_loadout(team: int) -> Dictionary:
	var primary := "kv14" if team == GameTypes.Team.POLICE else "vec9"
	return {
		"primary": primary,
		"secondary": "p9",
		"gadget": "flash",
		"armor": 1,
		"medkits": 1,
		"ammo_boxes": 0,
	}


# ----------------------------------------------------------------------------

func _spawn_characters() -> void:
	var entries: Array = config["players"]
	var crim_index := 0
	var cop_index := 0
	for entry in entries:
		var team := int(entry.get("team", GameTypes.Team.CRIMINALS))
		if team == deferred_team:
			continue
		var spawn_tiles: Array = map_data.spawn_crim if team == GameTypes.Team.CRIMINALS else map_data.spawn_cop
		if spawn_tiles.is_empty():
			spawn_tiles = map_data.spawn_cop if team == GameTypes.Team.CRIMINALS else map_data.spawn_crim
		var tile: Vector2i = spawn_tiles[crim_index % spawn_tiles.size()] if team == GameTypes.Team.CRIMINALS else spawn_tiles[cop_index % spawn_tiles.size()]
		if team == GameTypes.Team.CRIMINALS:
			crim_index += 1
		else:
			cop_index += 1
		var character := _spawn_character(entry, tile)
		characters.append(character)
		if bool(entry.get("controlled", false)):
			local_player = character
			local_team = team
			local_controller = load("res://scripts/core/player_controller.gd").new()
			local_controller.character = character
			local_controller.match_ref = self
			character.add_child(local_controller)
			character.controlled = true
			camera.global_position = character.global_position
		elif bool(entry.get("is_bot", false)):
			var bot: BotController = load("res://scripts/ai/bot_controller.gd").new(character, self, int(entry.get("difficulty", 1)))
			character.add_child(bot)
			character.is_bot = true
			character.controller = bot
		else:
			# Remote player: driven by network replication.
			character.player_id = int(entry.get("id", 0))
	players = characters.duplicate()


func _spawn_character(entry: Dictionary, tile: Vector2i) -> Character:
	var character := Character.new()
	var world := get_node("World")
	world.add_child(character)
	character.global_position = map_data.tile_center_world(tile.x, tile.y)
	character.match_ref = self
	character.setup(entry)
	character.player_id = int(entry.get("id", 0))
	return character


func _spawn_civilians() -> void:
	if not bool(config.get("civilians", true)):
		return
	var count := int(config.get("civilian_count", 8))
	var types: Array = Data.map(String(config.get("map", "clinic"))).get("civilians", ["staff", "visitor"])
	if types.is_empty():
		types = ["staff", "visitor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.get("seed", 1)) + 555
	var tiles: Array = []
	for room_index in range(map_data.rooms.size()):
		var room: Dictionary = map_data.rooms[room_index]
		if room_index % 2 == 0:
			continue
		var floor_tiles: Array = room["floor_tiles"]
		if floor_tiles.is_empty():
			continue
		var tile: Vector2i = floor_tiles[rng.randi() % floor_tiles.size()]
		tiles.append(tile)
		if tiles.size() >= count:
			break
	while tiles.size() < count:
		var x := rng.randi_range(2, map_data.width - 3)
		var y := rng.randi_range(2, map_data.height - 3)
		if map_data.is_walkable(x, y):
			tiles.append(Vector2i(x, y))
		if tiles.size() > count * 3:
			break
	for i in mini(count, tiles.size()):
		var civ := Character.new()
		get_node("World").add_child(civ)
		civ.global_position = map_data.tile_center_world(tiles[i].x, tiles[i].y)
		civ.match_ref = self
		var civ_type := Data.civilian(String(types[i % types.size()]))
		if civ_type.is_empty():
			civ_type = Data.civilian("staff")
		civ.setup({
			"name": String(civ_type.get("name", "Гражданский")),
			"team": GameTypes.Team.CIVILIAN,
			"is_bot": true,
			"loadout": {},
		})
		civ.collision_layer = 8
		civ.collision_mask = 1 | 2 | 4 | 16
		civ.speed_scale = float(civ_type.get("speed", 85)) / Character.WALK_SPEED
		var controller: CivilianController = load("res://scripts/ai/civilian_controller.gd").new(civ, self, float(civ_type.get("confidence", 0.4)))
		civ.add_child(controller)
		civ.controller = controller
		controller.home_pos = civ.global_position
		controller.state = GameTypes.NPCState.ROUTINE
		characters.append(civ)
	civilian_total = characters.size() - players.size()


# ----------------------------------------------------------------------------

func spawn_deferred_team(team: int) -> void:
	var entries: Array = config["players"]
	var points := _deferred_spawn_points(team)
	var index := 0
	for entry in entries:
		var entry_team := int(entry.get("team", GameTypes.Team.CRIMINALS))
		if entry_team != team:
			continue
		var already := false
		for c in characters:
			if c.player_id == int(entry.get("id", 0)) and int(entry.get("id", 0)) != 0:
				already = true
				break
		if already:
			index += 1
			continue
		var tile: Vector2i = points[index % maxi(1, points.size())] if not points.is_empty() else Vector2i(2, 2)
		index += 1
		var character := _spawn_character(entry, tile)
		characters.append(character)
		if bool(entry.get("controlled", false)):
			local_player = character
			local_team = team
			local_controller = load("res://scripts/core/player_controller.gd").new()
			local_controller.character = character
			local_controller.match_ref = self
			character.add_child(local_controller)
			character.controlled = true
			camera.global_position = character.global_position
		elif bool(entry.get("is_bot", false)):
			var bot: BotController = load("res://scripts/ai/bot_controller.gd").new(character, self, int(entry.get("difficulty", 1)))
			character.add_child(bot)
			character.is_bot = true
			character.controller = bot
	feed(Localization.t("feed_police_arrived"))
	AudioManager.play("siren", Vector2.INF, -8.0)
	resonance.add_alarm(Vector2.ZERO)


func _deferred_spawn_points(team: int) -> Array:
	var out: Array = []
	for y in map_data.height:
		for x in map_data.width:
			var t := map_data.tile_at(x, y)
			if (t == MapData.Tile.ROAD or t == MapData.Tile.OUTSIDE) and map_data.is_walkable(x, y):
				out.append(Vector2i(x, y))
	if out.is_empty():
		return map_data.spawn_cop if team == GameTypes.Team.POLICE else map_data.spawn_crim
	return out


func give_weapon(character: Character, weapon_id: String) -> void:
	var wdata := Data.weapon(weapon_id)
	if wdata.is_empty():
		return
	var weapon := Weapon.new(wdata)
	if character.weapons.size() > 2:
		character.weapons[0] = weapon
	else:
		character.weapons.append(weapon)
	character.weapon_index = 0
	character.weapon_changed.emit(weapon)
	character.ammo_changed.emit(weapon)


func _process(delta: float) -> void:
	if paused or finished:
		return
	elapsed += delta
	_mouse_world = get_mouse_world()
	noise.update(delta)
	fog.update(self, delta)
	resonance.update(delta, self)
	if mode != null:
		mode.update(delta)
	_update_effects(delta)
	_update_respawns(delta)
	_update_camera(delta)
	if replay != null:
		replay.update(delta)
	if hud != null:
		hud.update_hud(self, delta)


func _physics_process(_delta: float) -> void:
	pass


# ---- phases ----------------------------------------------------------------

func set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_time = 0.0
	match new_phase:
		GameTypes.GamePhase.PREP:
			feed(Localization.t("phase_prep"))
			if mode != null:
				mode.on_prep()
		GameTypes.GamePhase.ACTIVE:
			feed(Localization.t("phase_active"))
			if mode != null:
				mode.on_active()
		GameTypes.GamePhase.POST:
			feed(Localization.t("phase_post"))
			if mode != null:
				mode.on_post()
		GameTypes.GamePhase.RESULTS:
			_finish()
	phase_changed.emit(phase)


func advance_phase_timer(delta: float) -> void:
	phase_time += delta
	if phase == GameTypes.GamePhase.PREP and phase_time >= PREP_TIME:
		set_phase(GameTypes.GamePhase.ACTIVE)
	elif phase == GameTypes.GamePhase.POST and phase_time >= POST_TIME:
		set_phase(GameTypes.GamePhase.RESULTS)


# ---- combat ----------------------------------------------------------------

func fire_bullet(shooter: Character, from: Vector2, dir: Vector2, weapon: Weapon) -> void:
	if map_data == null:
		return
	var range_px: float = weapon.range
	var tile_dist := _tile_hit_distance(from, dir, range_px)
	var params := PhysicsRayQueryParameters2D.create(from, from + dir * range_px)
	params.collision_mask = 1 | 2 | 4 | 8
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [shooter.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(params)
	var end := from + dir * range_px
	var hit_character: Character = null
	if hit:
		end = hit.position
		if tile_dist >= 0.0 and end.distance_to(from) > tile_dist:
			end = from + dir * tile_dist
			_on_tile_hit(from + dir * tile_dist, dir, weapon)
		else:
			var collider = hit.collider
			if collider is Character and collider != shooter:
				hit_character = collider
	elif tile_dist >= 0.0:
		end = from + dir * tile_dist
		_on_tile_hit(end, dir, weapon)
	_spawn_tracer(from + dir * 20.0, end)
	if hit_character != null:
		var dist := from.distance_to(end)
		var falloff := clampf(1.0 - dist / maxf(1.0, range_px), 0.35, 1.0)
		var damage := weapon.damage * falloff
		if hit_character.team == shooter.team and not bool(config.get("friendly_fire", false)):
			return
		hit_character.apply_damage(damage, shooter, dir)


func _tile_hit_distance(from: Vector2, dir: Vector2, max_dist: float) -> float:
	var step := 16.0
	var d := step
	while d <= max_dist:
		var p := from + dir * d
		var tile := map_data.world_to_tile(p)
		if map_data.blocks_bullets(tile.x, tile.y):
			if map_data.tile_at(tile.x, tile.y) == MapData.Tile.GLASS:
				return d
			return d
		d += step
	return -1.0


func _on_tile_hit(pos: Vector2, dir: Vector2, weapon: Weapon) -> void:
	var tile := map_data.world_to_tile(pos)
	if map_data.tile_at(tile.x, tile.y) == MapData.Tile.GLASS:
		map_data.set_tile(tile.x, tile.y, MapData.Tile.FLOOR, 0)
		map_view.refresh_tile(tile)
		spawn_blood(pos, dir, 0)
		play_sound("glass_break", pos, -8.0)
		noise.add_noise(pos, 0.7, 420.0, null)
		resonance.add_noise_event(pos, 0.6)


func melee_hit(shooter: Character, dir: Vector2, range_px: float, damage: float) -> Character:
	var best: Character = null
	var best_d := 1e9
	for other in characters:
		if other == shooter or not other.alive:
			continue
		var to := other.global_position - shooter.global_position
		var dist := to.length()
		if dist > range_px:
			continue
		if absf(U.angle_diff(dir.angle(), to.angle())) > 0.8:
			continue
		if not map_data.has_los(shooter.global_position, other.global_position):
			continue
		if dist < best_d:
			best_d = dist
			best = other
	if best != null:
		if best.team == shooter.team and not bool(config.get("friendly_fire", false)):
			return null
		best.apply_damage(damage, shooter, dir)
	return best


func add_suppression_around(pos: Vector2, radius: float) -> void:
	for c in characters:
		if not c.alive:
			continue
		var d := c.global_position.distance_to(pos)
		if d < radius:
			c.add_suppression((1.0 - d / radius) * 0.7)


func use_gadget(character: Character, gadget_id: String) -> void:
	var pos := character.global_position
	match gadget_id:
		"flash":
			_spawn_effect("fx_flash", pos, 0.4, 3.0)
			add_suppression_around(pos, 420.0)
			play_sound("flashbang", pos, -2.0)
			resonance.add_noise_event(pos, 0.5)
		"smoke":
			smoke_zones.append({"pos": pos, "radius": 260.0, "time": 18.0})
			_spawn_effect("fx_smoke", pos, 18.0, 2.0)
			play_sound("smoke", pos, -6.0)
		"medkit":
			character.heal(55)
			play_sound("heal", pos)
			announce("healed", character.char_name)
		"ammo":
			for w in character.weapons:
				w.reserve += int(w.data.get("reserve", 0)) / 2
			announce("ammo_given", character.char_name)
		"armor":
			character.max_armor = maxi(character.max_armor, 75)
			character.armor = character.max_armor
			announce("armor_on", character.char_name)
		"camera":
			for other in characters:
				if other.team == character.team or not other.alive:
					continue
				if other.global_position.distance_to(pos) < 520.0 and map_data.has_los(pos, other.global_position):
					fog.detected[character.team][other] = {"pos": other.global_position, "timer": 6.0, "uncertain": false}
			announce("camera_scan", character.char_name)
		"breach":
			for door in map_view.get_doors():
				if door.global_position.distance_to(pos) < 200.0:
					door.locked = false
					door.set_open(true)
			play_sound("door_open", pos)
		"radio":
			resonance.value = clampf(resonance.value - 8.0, 0.0, 100.0)
			for c in characters:
				if c.team == GameTypes.Team.CIVILIAN and c.controller != null and c.global_position.distance_to(pos) < 500.0:
					c.controller.command("calm", character)
			announce("calmed", character.char_name)
	# consume one charge
	if character.gadgets.has(gadget_id):
		character.gadgets[gadget_id] = int(character.gadgets[gadget_id]) - 1
		if int(character.gadgets[gadget_id]) <= 0:
			character.gadgets.erase(gadget_id)


## Closed doors block movement; characters open them automatically when close.
func open_doors_near(character: Character, radius: float = 78.0) -> void:
	if map_view == null:
		return
	for door in map_view.get_doors():
		if door.locked or door.open:
			continue
		if door.global_position.distance_to(character.global_position) <= radius:
			door.set_open(true)
			play_sound("door_open", door.global_position, -10.0)


func is_in_smoke(pos: Vector2) -> bool:
	for zone in smoke_zones:
		if pos.distance_to(zone["pos"]) < float(zone["radius"]):
			return true
	return false


# ---- effects ---------------------------------------------------------------

func spawn_flash(pos: Vector2, dir: Vector2) -> void:
	if not SettingsManager.get_setting("flash_effects"):
		return
	var node := Sprite2D.new()
	node.texture = load("res://assets/textures/fx_flash.png")
	node.position = pos
	node.rotation = dir.angle()
	node.z_index = 20
	effect_root.add_child(node)
	effects.append({"node": node, "time": 0.06, "fade": true})


func spawn_blood(pos: Vector2, dir: Vector2, amount: int) -> void:
	if int(SettingsManager.get_setting("blood_level")) <= 0:
		return
	var count := amount * (1 if int(SettingsManager.get_setting("blood_level")) == 1 else 2)
	for i in count:
		var node := Sprite2D.new()
		var tex: Texture2D = load("res://assets/textures/fx_blood_%d.png" % (1 + (randi() % 3)))
		node.texture = tex
		node.position = pos + Vector2(randf_range(-14, 14), randf_range(-14, 14))
		node.rotation = dir.angle() + randf_range(-0.6, 0.6)
		node.scale = Vector2.ONE * randf_range(0.5, 1.1)
		node.z_index = -2
		decal_root.add_child(node)
		decals.append(node)
	while decals.size() > MAX_DECALS:
		var old: Sprite2D = decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func spawn_shell(pos: Vector2) -> void:
	if decals.size() >= MAX_DECALS:
		return
	var node := Sprite2D.new()
	node.texture = load("res://assets/textures/fx_shell.png")
	node.position = pos
	node.rotation = randf() * TAU
	node.scale = Vector2(0.7, 0.7)
	node.z_index = -1
	decal_root.add_child(node)
	decals.append(node)


func _spawn_effect(texture_name: String, pos: Vector2, time: float, scale_factor: float) -> void:
	var node := Sprite2D.new()
	node.texture = load("res://assets/textures/%s.png" % texture_name)
	node.position = pos
	node.scale = Vector2.ONE * scale_factor
	node.z_index = 15
	effect_root.add_child(node)
	effects.append({"node": node, "time": time, "fade": true})


func _spawn_tracer(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 2.0
	line.default_color = Color(1.0, 0.85, 0.5, 0.55)
	line.z_index = 12
	tracer_root.add_child(line)
	effects.append({"node": line, "time": 0.07, "fade": true})


func _update_effects(delta: float) -> void:
	var i := effects.size() - 1
	while i >= 0:
		var e: Dictionary = effects[i]
		e["time"] = float(e["time"]) - delta
		var node: Node2D = e["node"]
		if is_instance_valid(node) and bool(e.get("fade", false)):
			var sprite: Sprite2D = node as Sprite2D
			if sprite != null:
				sprite.modulate.a = clampf(float(e["time"]) * 6.0, 0.0, 1.0)
			else:
				var line: Line2D = node as Line2D
				if line != null:
					line.default_color.a = clampf(float(e["time"]) * 8.0, 0.0, 1.0)
		if float(e["time"]) <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			effects.remove_at(i)
		i -= 1
	var j := smoke_zones.size() - 1
	while j >= 0:
		smoke_zones[j]["time"] = float(smoke_zones[j]["time"]) - delta
		if float(smoke_zones[j]["time"]) <= 0.0:
			smoke_zones.remove_at(j)
		j -= 1


# ---- sound -----------------------------------------------------------------

func play_sound(sound_name: String, pos: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SettingsManager.get_setting("sfx_enabled"):
		return
	var attenuated := volume_db
	if pos != Vector2.INF and local_player != null:
		var d := local_player.global_position.distance_to(pos)
		attenuated -= clampf(d / 900.0, 0.0, 1.0) * 22.0
	AudioManager.play(sound_name, pos, attenuated, pitch)


func play_footstep(character: Character, crouching: bool, sprinting: bool) -> void:
	var tile := map_data.world_to_tile(character.global_position)
	var variant := int(map_data.variant[map_data.idx(tile.x, tile.y)]) if map_data.in_bounds(tile.x, tile.y) else 0
	var surface := "footstep_concrete"
	match map_data.tile_at(tile.x, tile.y):
		MapData.Tile.FLOOR:
			surface = "footstep_wood" if variant == 2 else ("footstep_concrete" if variant == 0 else "footstep_metal")
		MapData.Tile.ROAD, MapData.Tile.OUTSIDE:
			surface = "footstep_concrete"
		MapData.Tile.GRATE:
			surface = "footstep_metal"
	var vol := -14.0
	if sprinting:
		vol = -4.0
	elif crouching:
		vol = -24.0
	play_sound(surface, character.global_position, vol, randf_range(0.92, 1.08))


# ---- interactions ----------------------------------------------------------

func find_interactable(character: Character, range_px: float):
	var best = null
	var best_d := range_px
	for item in interactables:
		if not is_instance_valid(item) or not item.can_use(character):
			continue
		var d: float = character.global_position.distance_to(item.global_position)
		if d < best_d and map_data.has_los(character.global_position, item.global_position):
			best_d = d
			best = item
	for door in map_view.get_doors():
		if door.locked or not door.can_use(character):
			continue
		var d: float = character.global_position.distance_to(door.global_position)
		if d < best_d and map_data.has_los(character.global_position, door.global_position):
			best_d = d
			best = door
	for c in characters:
		if c.team != GameTypes.Team.CIVILIAN or not c.alive:
			continue
		var wrapper: Interactable.InteractCivilian = _civ_wrappers.get(c)
		if wrapper == null:
			wrapper = Interactable.InteractCivilian.new(self, c)
			wrapper.visible = false
			get_node("World").add_child(wrapper)
			_civ_wrappers[c] = wrapper
		wrapper.position = c.global_position
		var d: float = character.global_position.distance_to(c.global_position)
		if d < best_d and map_data.has_los(character.global_position, c.global_position):
			best_d = d
			best = wrapper
	return best


func register_interactable(item) -> void:
	interactables.append(item)


func objective_position() -> Vector2:
	if mode != null:
		return mode.get_focus_position()
	if not map_data.objectives.is_empty():
		return map_data.objectives[0]["pos"]
	return Vector2.INF


# ---- announcements ---------------------------------------------------------

func announce(type: String, who: String = "") -> void:
	var text := ""
	match type:
		"bot_investigate":
			text = Localization.t("feed_investigate") % who
		"bot_ack":
			text = Localization.t("feed_order_ack") % who
		"healed":
			text = Localization.t("feed_healed") % who
		"ammo_given":
			text = Localization.t("feed_ammo") % who
		"armor_on":
			text = Localization.t("feed_armor") % who
		"camera_scan":
			text = Localization.t("feed_camera") % who
		"calmed":
			text = Localization.t("feed_calmed") % who
		"civ_ack":
			text = Localization.t("feed_civ_ack") % who
		"civ_report":
			text = Localization.t("feed_civ_report") % who
		"loot_taken":
			text = Localization.t("feed_loot") % who
		"device_planted":
			text = Localization.t("feed_planted") % who
		"device_defused":
			text = Localization.t("feed_defused") % who
		"hostage_freed":
			text = Localization.t("feed_hostage") % who
		_:
			text = who
	if not text.is_empty():
		feed(text)


func announce_order(character: Character, type: int) -> void:
	announce("bot_ack", character.char_name)


func feed(text: String) -> void:
	_feed.append(text)
	if _feed.size() > 6:
		_feed.pop_front()
	feed_message.emit(text)
	if hud != null:
		hud.add_feed(text)


func hint(text: String) -> void:
	if text == _hint_text:
		return
	_hint_text = text
	hint_changed.emit(text)
	if hud != null:
		hud.set_hint(text)


func get_hint() -> String:
	return _hint_text


# ---- deaths ----------------------------------------------------------------

func on_character_died(victim: Character, killer: Character) -> void:
	if killer != null and killer != victim:
		record_stat(killer, "kills")
	record_stat(victim, "deaths")
	if mode != null:
		mode.on_character_died(victim, killer)
	if victim.team == GameTypes.Team.CIVILIAN:
		resonance.add_civilian_hurt()
		feed(Localization.t("feed_civilian_down"))
		if killer != null and killer.team == GameTypes.Team.CRIMINALS:
			resonance.value = clampf(resonance.value + 25.0, 0.0, 100.0)
	elif killer != null and killer.team != victim.team:
		feed(Localization.t("feed_kill") % [killer.char_name, victim.char_name])
		if replay != null:
			replay.record_event("kill", {"killer": killer.char_name, "victim": victim.char_name, "team": victim.team})
	if victim.carry_object:
		victim.carry_object = false
		if mode != null:
			mode.on_carrier_down(victim)
	if victim.controlled:
		_on_local_player_died(victim, killer)
	if bool(config.get("respawn", false)) and victim.team != GameTypes.Team.CIVILIAN:
		respawn_queue.append({"character": victim, "time": RESPAWN_TIME})


func on_character_downed(character: Character, killer: Character) -> void:
	feed(Localization.t("feed_downed") % character.char_name)
	if character.controlled:
		death_screen_requested.emit({"downed": true, "character": character})


func _on_local_player_died(victim: Character, killer: Character) -> void:
	var bots: Array = []
	for c in characters:
		if c.is_bot and c.team == victim.team and c.alive:
			bots.append(c)
	death_screen_requested.emit({"downed": false, "character": victim, "bots": bots})


func _update_respawns(delta: float) -> void:
	var i := respawn_queue.size() - 1
	while i >= 0:
		var entry: Dictionary = respawn_queue[i]
		entry["time"] = float(entry["time"]) - delta
		if float(entry["time"]) <= 0.0:
			var character: Character = entry["character"]
			respawn_queue.remove_at(i)
			if not finished and is_instance_valid(character):
				_respawn(character)
		i -= 1


func _respawn(character: Character) -> void:
	var team := character.team
	var tiles: Array = map_data.spawn_crim if team == GameTypes.Team.CRIMINALS else map_data.spawn_cop
	var tile: Vector2i = tiles[randi() % maxi(1, tiles.size())]
	character.global_position = map_data.tile_center_world(tile.x, tile.y)
	character.alive = true
	character.downed = false
	character.hp = character.max_hp
	character.armor = character.max_armor
	character.collision_layer = 2 | 4
	character.collision_mask = 1 | 2 | 4 | 8
	if character.sprite != null:
		character.sprite.modulate = Color.WHITE
		character.sprite.rotation = 0.0
	character.health_changed.emit(character.hp, character.max_hp)
	feed(Localization.t("feed_respawn") % character.char_name)


# ---- bot control -----------------------------------------------------------

func take_bot_control(bot: Character) -> void:
	if bot.controller != null and bot.controller is BotController:
		bot.controller.active = false
	var controller: PlayerController = load("res://scripts/core/player_controller.gd").new()
	controller.character = bot
	controller.match_ref = self
	bot.add_child(controller)
	bot.controlled = true
	bot.is_bot = false
	local_player = bot
	local_controller = controller
	feed(Localization.t("feed_take_control") % bot.char_name)


func spectate_character(character: Character) -> void:
	if character != null and character.alive:
		camera.global_position = character.global_position


# ---- civilians -------------------------------------------------------------

func on_civilian_report(civilian: Character, pos: Vector2) -> void:
	announce("civ_report", civilian.char_name)
	feed(Localization.t("feed_civ_report") % civilian.char_name)
	resonance.add_alarm(pos)
	# Police receive an approximate area, never exact coordinates.
	for c in characters:
		if c.team == GameTypes.Team.POLICE and c.alive and c.controller != null and c.controller.has_method("set_order"):
			var offset := Vector2(randf_range(-140, 140), randf_range(-140, 140))
			c.controller.set_order(GameTypes.OrderType.MOVE, {"pos": pos + offset})


func on_civilian_evacuated(civilian: Character) -> void:
	resonance.add_civilian_evacuated()
	if mode != null:
		mode.on_civilian_evacuated(civilian)


# ---- objectives ------------------------------------------------------------

func on_device_planted(device, character: Character) -> void:
	announce("device_planted", character.char_name)
	if replay != null:
		replay.record_event("objective", {"kind": "plant", "who": character.char_name})
	if mode != null:
		mode.on_device_planted(device, character)


func on_device_defused(device, character: Character) -> void:
	announce("device_defused", character.char_name)
	if mode != null:
		mode.on_device_defused(device, character)


func on_loot_picked(loot, character: Character) -> void:
	announce("loot_taken", character.char_name)
	if replay != null:
		replay.record_event("objective", {"kind": "loot", "who": character.char_name})
	loot.enabled = false
	character.carry_object = true
	if mode != null:
		mode.on_loot_picked(loot, character)


func on_zone_captured(zone, team: int) -> void:
	feed(Localization.t("feed_zone") % GameTypes.team_name(team))
	if mode != null:
		mode.on_zone_captured(zone, team)


func on_hostage_freed(interactable, character: Character) -> void:
	announce("hostage_freed", character.char_name)
	if mode != null:
		mode.on_hostage_freed(interactable, character)


func open_civilian_commands(character: Character, civilian: Character) -> void:
	if hud != null:
		hud.open_civilian_commands(character, civilian)


func open_negotiation(character: Character) -> void:
	if hud != null:
		hud.open_negotiation(character)


func on_bot_spotted(bot: Character, target: Character) -> void:
	if bot.team == GameTypes.Team.POLICE:
		feed(Localization.t("feed_spotted") % bot.char_name)


# ---- camera ----------------------------------------------------------------

func get_mouse_world() -> Vector2:
	if camera == null:
		return _mouse_world
	return camera.get_global_mouse_position()


func add_camera_kick(dir: Vector2, amount: float) -> void:
	if not SettingsManager.get_setting("screen_shake"):
		return
	_camera_offset -= dir * amount * 14.0
	_camera_shake = minf(1.0, _camera_shake + amount * 0.5)


func shake_camera(amount: float) -> void:
	if not SettingsManager.get_setting("screen_shake"):
		return
	_camera_shake = minf(1.0, _camera_shake + amount)


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target: Node2D = local_player
	if target == null or not is_instance_valid(target) or not target.alive:
		var spectate := _first_alive_teammate()
		if spectate != null:
			target = spectate
	if target != null:
		camera.position = camera.position.lerp(target.global_position, clampf(delta / maxf(0.01, float(SettingsManager.get_setting("camera_lag"))), 0.0, 1.0))
	_camera_offset = _camera_offset.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	_camera_shake = maxf(0.0, _camera_shake - delta * 2.2)
	var shake := Vector2.ZERO
	if _camera_shake > 0.0:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _camera_shake * 9.0
	camera.offset = _camera_offset + shake
	var zoom_target := float(SettingsManager.get_setting("camera_zoom"))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * zoom_target, clampf(delta * 3.0, 0.0, 1.0))


func _first_alive_teammate() -> Character:
	if local_player == null:
		return null
	for c in characters:
		if c.team == local_player.team and c.alive:
			return c
	return null


# ---- finish ----------------------------------------------------------------

func end_match(winner_team: int, reason_key: String, winner_character: Character = null) -> void:
	if finished:
		return
	finished = true
	var results := {
		"winner": winner_team,
		"reason": Localization.t(reason_key),
		"reason_key": reason_key,
		"mode": String(config.get("mode", "plant")),
		"map": String(config.get("map", "clinic")),
		"map_name": map_data.map_name if map_data != null else "",
		"duration": elapsed,
		"team_criminals": _team_score(GameTypes.Team.CRIMINALS),
		"team_police": _team_score(GameTypes.Team.POLICE),
		"players": [],
		"civ_saved": 0,
		"civ_hurt": 0,
		"local_team": local_team,
		"outcome": "draw",
		"winner_name": winner_character.char_name if winner_character != null else GameTypes.team_name(winner_team),
		"ffa": bool(config.get("ffa", false)),
	}
	var local_won: bool = false
	if bool(config.get("ffa", false)):
		local_won = winner_character != null and winner_character == local_player
	else:
		local_won = winner_team == local_team
	results["outcome"] = "win" if local_won else ("loss" if winner_team != GameTypes.Team.NONE else "draw")
	for c in characters:
		if c.team == GameTypes.Team.CIVILIAN:
			if not c.alive:
				results["civ_hurt"] = int(results["civ_hurt"]) + 1
			continue
		results["players"].append({
			"name": c.char_name,
			"team": c.team,
			"is_bot": c.is_bot,
			"controlled": c.controlled,
			"role": c.role,
			"kills": _char_kills(c),
			"deaths": _char_deaths(c),
			"assists": 0,
			"civ_saved": 0,
			"objectives": _char_objectives(c),
		})
	if mode != null:
		results["highlights"] = mode.get_highlights()
	ProfileManager.add_result(results)
	if replay != null:
		replay.stop()
	set_phase(GameTypes.GamePhase.RESULTS)
	match_finished.emit(results)


func _finish() -> void:
	if finished:
		return
	finished = true
	if replay != null:
		replay.stop()


func _team_score(team: int) -> int:
	if mode != null:
		return int(mode.get_score(team))
	return 0


func _char_kills(character: Character) -> int:
	return int(stats.get(str(character.player_id), {}).get("kills", 0)) if character.player_id != 0 else int(stats.get(character.char_name, {}).get("kills", 0))


func _char_deaths(character: Character) -> int:
	return int(stats.get(str(character.player_id), {}).get("deaths", 0)) if character.player_id != 0 else int(stats.get(character.char_name, {}).get("deaths", 0))


func _char_objectives(character: Character) -> int:
	return int(stats.get(str(character.player_id), {}).get("objectives", 0)) if character.player_id != 0 else int(stats.get(character.char_name, {}).get("objectives", 0))


func record_stat(character: Character, key: String, amount: int = 1) -> void:
	var id := str(character.player_id) if character.player_id != 0 else character.char_name
	if not stats.has(id):
		stats[id] = {"kills": 0, "deaths": 0, "objectives": 0}
	stats[id][key] = int(stats[id].get(key, 0)) + amount


# ---- pause -----------------------------------------------------------------

func ping(pos: Vector2) -> void:
	feed(Localization.t("feed_ping"))
	AudioManager.play("radio_blip", pos, -10.0)
	var marker := Sprite2D.new()
	marker.texture = load("res://assets/textures/marker_objective.png")
	marker.position = pos
	marker.scale = Vector2(0.7, 0.7)
	marker.z_index = 14
	effect_root.add_child(marker)
	effects.append({"node": marker, "time": 6.0, "fade": true})
	issue_order(GameTypes.OrderType.MOVE, {"pos": pos})


func handle_order_selected(type: int) -> void:
	var data: Dictionary = {}
	match type:
		GameTypes.OrderType.MOVE, GameTypes.OrderType.COVER:
			data = {"pos": get_mouse_world()}
		GameTypes.OrderType.HELP:
			data = {"character": _nearest_downed_teammate()}
		GameTypes.OrderType.INTERACT:
			data = {"interactable": find_interactable(local_player, 420.0)}
		GameTypes.OrderType.FOLLOW, GameTypes.OrderType.GATHER, GameTypes.OrderType.ESCORT:
			data = {"character": local_player}
	issue_order(type, data)


func _nearest_downed_teammate() -> Character:
	if local_player == null:
		return null
	var best: Character = null
	var best_d := 1e9
	for c in characters:
		if c.team == local_player.team and c.downed:
			var d := c.global_position.distance_to(local_player.global_position)
			if d < best_d:
				best_d = d
				best = c
	return best


func issue_order(type: int, data: Dictionary = {}) -> void:
	for c in characters:
		if c.team != local_team or not c.alive:
			continue
		if c.controller != null and c.controller is BotController:
			c.controller.set_order(type, data)
	resonance.add_noise_event(local_player.global_position if local_player != null else Vector2.ZERO, 0.1)


func round_time_left() -> float:
	match phase:
		GameTypes.GamePhase.PREP:
			return maxf(0.0, PREP_TIME - phase_time)
		GameTypes.GamePhase.ACTIVE:
			var rt := mode.round_time if mode != null else 0.0
			return maxf(0.0, rt - phase_time)
		GameTypes.GamePhase.POST:
			return maxf(0.0, POST_TIME - phase_time)
	return 0.0


func toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	pause_requested.emit()
