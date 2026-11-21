class_name MatchWorld
extends Node2D
## The match. Builds the level, spawns every actor, owns combat resolution,
## objectives, the alarm/escalation system, bot commands, player possession,
## fog-of-war vision, the replay buffer and the win conditions.
##
## One MatchWorld == one round (or one arcade match). Mode scripts plug in through
## `mode` and only decide objectives and scoring; all mechanics live here so bots
## and humans always obey the same rules.

signal setup_done()

const KILL_CLIP_SECONDS := 5.0
const CLIP_HZ := 12.0
const MAX_CLIP_FRAMES := 70

var cfg: Dictionary = {}
var map: GeneratedMap
var visual: MapVisual
var effects: Effects
var cam: Camera2D
var actors: Array[Actor] = []
var doors: Array[Door] = []
var explosives: Array[ExplosiveProp] = []
var bags: Array[Node2D] = []
var mode: Node
var hud: Node
var local_actor: ActorPlayer
var possessed: Actor = null
var match_over := false
var elapsed := 0.0
var actors_root: Node2D
var fx_root: Node2D
var noise_events: Array[Dictionary] = []
var last_noise_pos := Vector2.ZERO
var last_noise_kind := ""
var alarm_level := 0
var alarm_reason := ""
var police_arrive_timer := -1.0
var police_arrived := false
var police_delay := 180.0
var team_score := {0: 0, 1: 0}
var round_index := 1
var intermission := 0.0
var killfeed: Array[Dictionary] = []
var camp = null
var rng := RandomNumberGenerator.new()
var next_actor_id := 1
var bot_brains: Array[BotBrain] = []
var orders: Dictionary = {}
var corpses: Array[Actor] = []
var clip_buffer: Array[Dictionary] = []
var clip_accum := 0.0
var best_clip: Dictionary = {}
var recent_kills: Array[Dictionary] = []
var replays: Array[Dictionary] = []
var player_possessions_left := 2
var paused := false
var _vis_accum := 0.0
var _vis_frame := 0
var _snap_accum := 0.0
var visible_enemies: Dictionary = {}
var last_known: Dictionary = {}
var team_vis_cells: Dictionary = {}
var spectator := false
var minimap_snapshot: Array = []
var minimap_corpses: Array = []
var camera_zoom := 1.0
var target_zoom := 1.0
var zoom_aspect := 1.15
var shake := 0.0
var shake_time := 0.0
var aim_point := Vector2.ZERO
var buy_open := false
var instant_death := false
var friendly_fire := false
var start_time := 0.0
var net: NetSession = null
var post_fx: Node = null
var fog: FogOverlay = null
var barricades: Array[Dictionary] = []
var drones: Array[Dictionary] = []
var roster: Array = []
var is_client := false
var pending_input: Dictionary = {}


func _ready() -> void:
	var config: Dictionary = GameFlow.match_config
	if config.is_empty():
		config = GameFlow.lobby_config.duplicate(true)
	if config.is_empty():
		config = {"mode": "heist", "map": "random", "team": 0, "bots_fill": true, "difficulty": 1}
	if not config.has("seed"):
		config["seed"] = randi()
	call_deferred("setup", config)


func setup(config: Dictionary) -> void:
	cfg = config.duplicate(true)
	var theme_id := str(cfg.get("map", "random"))
	if theme_id == "random" or not Db.MAPS.has(theme_id):
		theme_id = Db.MAP_ORDER[rng.randi_range(0, Db.MAP_ORDER.size() - 1)]
	var mode_id := str(cfg.get("mode", "heist"))
	rng.seed = int(cfg.get("rng_seed", 0))
	if rng.seed == 0:
		rng.seed = int(Time.get_unix_time_from_system()) ^ (OS.get_process_id() * 7919)
	var seed_val := int(cfg.get("seed", rng.randi()))
	cfg["seed"] = seed_val
	map = MapGen.generate(theme_id, seed_val, mode_id)
	var theme: Dictionary = map.theme
	var mode_data: Dictionary = Db.MODES.get(mode_id, Db.MODES["heist"])
	police_delay = float(mode_data.get("police_delay", 180.0))
	if bool(mode_data.get("police_on_start", false)):
		police_arrived = true
		police_arrive_timer = 0.0
	elif float(mode_data.get("police_delay", 0.0)) > 0.0:
		police_arrive_timer = police_delay

	visual = MapVisual.new()
	visual.name = "MapVisual"
	add_child(visual)
	visual.setup(map)

	actors_root = Node2D.new()
	actors_root.name = "Actors"
	actors_root.z_index = 10
	add_child(actors_root)
	fx_root = Node2D.new()
	fx_root.name = "FX"
	add_child(fx_root)

	effects = Effects.new()
	effects.map = map
	fx_root.add_child(effects)

	_build_doors()
	_build_explosives()
	var online_client := NetLink.is_online() and not NetLink.is_host
	if not online_client:
		_spawn_everyone()
	else:
		_build_offline_hud_shell()
	_build_camera()
	_build_hud()
	_build_mode(mode_id)
	_setup_replay_buffer()
	_build_post_fx()
	_build_fog_overlay()
	_net_boot()
	GameFlow.set_screen("match")
	Sfx.listener_pos = local_actor.global_position if local_actor != null else map.world_size() * 0.5
	Sfx.play_music("arcade" if str(mode_data.get("family", "")) == "arcade" else "heist")
	Sfx.start_ambience()
	set_physics_process(true)
	set_process(true)
	setup_done.emit()


# ---------------------------------------------------------------------------
# WORLD CONSTRUCTION
# ---------------------------------------------------------------------------

func _build_doors() -> void:
	for i in range(map.doors.size()):
		var d := Door.new()
		d.setup(map, map.doors[i], i, visual, self)
		add_child(d)
		doors.append(d)


func _build_explosives() -> void:
	for prop in map.props:
		var kind := str(prop["kind"])
		if kind in ["car", "barrel"]:
			var e := ExplosiveProp.new()
			var c: Vector2i = prop["cell"]
			e.setup("car" if kind == "car" else "barrel", map.cell_to_world(c), self, visual)
			explosives.append(e)
			add_child(e)
		elif kind in ["fridge", "vending_machine", "forklift"] and rng.randf() < 0.4:
			var e2 := ExplosiveProp.new()
			var c2: Vector2i = prop["cell"]
			e2.setup("gas", map.cell_to_world(c2), self, visual)
			explosives.append(e2)
			add_child(e2)


func _spawn_everyone() -> void:
	var mode_data: Dictionary = Db.MODES.get(str(cfg.get("mode", "heist")), Db.MODES["heist"])
	var family := str(mode_data.get("family", "heist"))
	var team := int(cfg.get("team", 0))
	var bot_difficulty := int(cfg.get("difficulty", 1))
	var bots_fill := bool(cfg.get("bots_fill", true))
	var size_team := 4
	if str(mode_data.get("players", "5v5")) == "6v6":
		size_team = 6
	elif str(mode_data.get("players", "5v5")) == "4v4":
		size_team = 4

	# --- human player ---
	var human_outfit := _outfit_for(mode_data, team, family)
	local_actor = ActorPlayer.new()
	local_actor.name = "Player"
	local_actor.configure(next_actor_id, GameFlow.player_codename, team, false)
	next_actor_id += 1
	actors_root.add_child(local_actor)
	actors.append(local_actor)
	local_actor.is_local_player = true
	_apply_loadout(local_actor, team, mode_data)
	local_actor.set_outfit(human_outfit)
	local_actor.world = self
	local_actor.map = map
	local_actor.set_meta("peer", NetLink.my_peer_id())
	local_actor.money = int(cfg.get("start_money", 2500))
	_place_actor(local_actor, team, true)

	# --- teammate bots ---
	var team_mates := size_team - 1
	if not bots_fill:
		team_mates = mini(team_mates, 1)
	for i in range(team_mates):
		var bot := _spawn_bot(team, mode_data, human_outfit, bot_difficulty, i)
		bot.ai.set("order", "follow" if family == "heist" else "advance")
		bot.ai.set("owner_player_id", local_actor.a_id)
		orders[bot.a_id] = "follow"

	# --- enemy team ---
	var enemies := size_team
	for i in range(enemies):
		var eteam := 1 - team
		var outfit := _outfit_for(mode_data, eteam, family)
		var eb := _spawn_bot(eteam, mode_data, outfit, bot_difficulty, i + 10)
		eb.ai.set("order", "advance" if eteam == 1 else "hold")

	# --- civilians ---
	var civ_count := int(mode_data.get("civilians", 6)) + int(cfg.get("civ_bonus", 0))
	if str(cfg.get("mode", "")) == "deathmatch":
		civ_count = 0
	var archetypes: Array = map.theme.get("civilians", ["bystander"])
	for i in range(civ_count):
		_spawn_civilian(archetypes, i)

	# --- hostages for hostage mode ---
	if str(cfg.get("mode", "")) == "hostage":
		for i in range(3):
			var h := _spawn_civilian(["office", "student"], i + 100, true)
			h.set_meta("hostage", true)
			h.is_hostage = true


func _outfit_for(mode_data: Dictionary, team: int, family: String) -> String:
	var mode_id := str(cfg.get("mode", ""))
	if team == Db.TEAM_CRIMINAL:
		if family == "arcade":
			return "arcade"
		match mode_id:
			"heist", "sabotage", "bomb_defuse":
				return "heist"
			"hostage":
				return "hostage"
			"siege":
				return "assault"
			"extraction", "vip":
				return "stealth"
		return GameFlow.profile.get("outfit_crim", "heist")
	else:
		match mode_id:
			"siege", "bomb_defuse":
				return "swat"
			"hostage":
				return "negotiator"
			"vip":
				return "ci"
			"heist":
				return "detective"
			"extraction":
				return "patrol"
			"domination", "deathmatch", "arms_race":
				return "riot" if mode_data.get("family", "") == "arcade" and rng.randf() < 0.5 else "swat"
		return GameFlow.profile.get("outfit_police", "swat")


func _apply_loadout(a: Actor, team: int, mode_data: Dictionary) -> void:
	var loadout_key := "loadout_crim" if team == Db.TEAM_CRIMINAL else "loadout_police"
	var kit: Dictionary = GameFlow.profile.get(loadout_key, GameFlow.DEFAULT_LOADOUT["crim" if team == 0 else "police"])
	if str(mode_data.get("family", "")) == "arcade":
		# arcade modes use curated kits, not the meta loadout
		if str(cfg.get("mode", "")) == "arms_race":
			kit = {"primary": "pm9", "secondary": "pm9", "melee": "knife", "armor": "none", "gadget_a": "smoke", "gadget_b": "flashbang", "perk": "runner"}
			a.set_meta("arms_race", true)
		else:
			kit = {"primary": "vk9" if team == 0 else "m4", "secondary": "pm9", "melee": "knife", "armor": "kevlar", "gadget_a": "grenade", "gadget_b": "flashbang", "perk": "ghost"}
	a.loadout.clear()
	var owned_perks: Array = []
	if GameFlow.profile.get("perks", []) is Array:
		for op in GameFlow.profile.get("perks", []):
			owned_perks.append(str(op))
	var kit_perk := str(kit.get("perk", ""))
	if kit_perk != "" and not owned_perks.has(kit_perk):
		owned_perks.append(kit_perk)
	a.setup_stats(owned_perks)
	a.add_weapon(str(kit.get("primary", "vk9")))
	a.add_weapon(str(kit.get("secondary", "pm9")))
	a.add_weapon(str(kit.get("melee", "knife")))
	a.equip_weapon(str(kit.get("primary", "vk9")))
	a.give_armor(str(kit.get("armor", "none")))
	a.gadget_charges = {}
	for g in ["grenade", "flashbang", "smoke", "molotov", "remote_charge"]:
		a.gadget_charges[g] = 0
	var g1 := str(kit.get("gadget_a", "flashbang"))
	var g2 := str(kit.get("gadget_b", "smoke"))
	a.gadget_charges[g1] = int(a.gadget_charges.get(g1, 0)) + 2
	a.gadget_charges[g2] = int(a.gadget_charges.get(g2, 0)) + 2
	# objective gadgets
	if team == Db.TEAM_CRIMINAL and str(cfg.get("mode", "")) in ["sabotage", "bomb_defuse"]:
		a.gadget_charges["c4"] = 1
	if team == Db.TEAM_CRIMINAL and str(cfg.get("mode", "")) in ["heist", "siege"]:
		a.gadget_charges["drill"] = 1
		a.gadget_charges["keycard"] = 1
	if team == Db.TEAM_POLICE:
		a.gadget_charges["breach_kit"] = 2
		a.gadget_charges["fortify"] = 1
		if str(kit.get("perk", "")) == "medic" or str(kit.get("perk", "")) == "comms":
			a.gadget_charges["medkit"] = 1
		if str(kit.get("perk", "")) == "comms":
			a.gadget_charges["drone"] = 1
	if str(kit.get("perk", "")) == "medic":
		# medics on both sides carry a medkit: the revive economy needs them
		a.gadget_charges["medkit"] = int(a.gadget_charges.get("medkit", 0)) + 1


func _spawn_bot(team: int, mode_data: Dictionary, outfit: String, difficulty: int, index: int) -> Actor:
	var b := Actor.new()
	var nm: String = Db.BOT_NAMES[(index * 5 + team * 3 + rng.randi_range(0, 7)) % Db.BOT_NAMES.size()]
	b.name = "Bot_%d" % next_actor_id
	b.configure(next_actor_id, nm, team, true)
	next_actor_id += 1
	actors_root.add_child(b)
	actors.append(b)
	b.world = self
	b.map = map
	b.set_outfit(outfit)
	_apply_loadout(b, team, mode_data)
	_place_actor(b, team, false, index)
	# bots get a perk roll so the player's choices have a counterpart
	if difficulty >= 2:
		var perk_pool := ["iron_lungs", "sharpshooter", "battering", "diversion", "ghost"]
		var picked := perk_pool[rng.randi_range(0, perk_pool.size() - 1)]
		if not b.perks.has(picked):
			b.perks.append(picked)
	var brain := BotBrain.new()
	brain.name = "Brain"
	b.add_child(brain)
	brain.setup(b, map, difficulty)
	b.ai = brain
	bot_brains.append(brain)
	# randomize gear a little so squads look varied
	if rng.randf() < 0.3:
		b.gadget_charges["smoke"] = int(b.gadget_charges.get("smoke", 0)) + 1
	if rng.randf() < 0.2:
		b.gadget_charges["molotov"] = int(b.gadget_charges.get("molotov", 0)) + 1
	return b


func _spawn_civilian(archetypes: Array, index: int, hostage: bool = false) -> Actor:
	var c := Actor.new()
	var arch_id := str(archetypes[index % archetypes.size()])
	var arch: Dictionary = Db.CIVILIAN_ARCHETYPES.get(arch_id, Db.CIVILIAN_ARCHETYPES["bystander"])
	var nm: String = Db.CIV_NAMES[(index * 3 + 1) % Db.CIV_NAMES.size()]
	c.name = "Civ_%d" % next_actor_id
	c.configure(next_actor_id, nm, Db.TEAM_CIVILIAN, true)
	next_actor_id += 1
	actors_root.add_child(c)
	actors.append(c)
	c.world = self
	c.map = map
	c.is_civilian = true
	c.setup_stats()
	c.hp = 60.0
	c.max_hp = 60.0
	c.visual.set_civilian(arch)
	c.speed_mult = float(arch.get("speed", 1.0))
	var cell := Vector2i(-1, -1)
	if map.spawns_civ.size() > 0:
		cell = map.spawns_civ[index % map.spawns_civ.size()]
	if cell == Vector2i(-1, -1):
		cell = map.world_to_cell(map.spawns_crim[0] if map.spawns_crim.size() > 0 else Vector2i(4, 4))
	c.global_position = map.cell_to_world(cell) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
	c.facing = rng.randf_range(0.0, TAU)
	var ai := CivilianAI.new()
	ai.name = "CivBrain"
	c.add_child(ai)
	ai.setup(c, map)
	c.ai = ai
	if hostage:
		c.set_meta("hostage", true)
		c.set_meta("hostage_state", "held")
	return c


func _place_actor(a: Actor, team: int, is_human: bool, index: int = 0) -> void:
	var cells: Array = map.spawns_crim if team == Db.TEAM_CRIMINAL else map.spawns_police
	# in heist/siege the criminals start inside the building, police outside
	var family := str(Db.MODES.get(str(cfg.get("mode", "heist")), {}).get("family", "heist"))
	if family == "heist":
		if team == Db.TEAM_CRIMINAL and not map.is_interior():
			pass
		elif team == Db.TEAM_CRIMINAL and map.rooms.size() > 0 and str(cfg.get("mode", "")) != "heist":
			var room: Dictionary = map.rooms[mini(map.rooms.size() - 1, 1 + index)]
			var rect: Rect2i = room["rect"]
			a.global_position = Vector2(rect.position + rect.size / 2) * GeneratedMap.TILE
			a.facing = PI * 0.5
			return
		elif team == Db.TEAM_CRIMINAL and map.rooms.size() > 0:
			var room2: Dictionary = map.rooms[mini(map.rooms.size() - 1, index)]
			var rect2: Rect2i = room2["rect"]
			a.global_position = Vector2(rect2.position + rect2.size / 2) * GeneratedMap.TILE
			a.facing = PI * 0.5
			return
	if cells.is_empty():
		a.global_position = map.cell_to_world(Vector2i(map.w / 2, map.h / 2))
		return
	var cell: Vector2i = cells[index % cells.size()]
	var base := map.cell_to_world(cell)
	var spread := Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18))
	a.global_position = base + spread
	if team == Db.TEAM_CRIMINAL:
		a.facing = -PI * 0.5
	else:
		a.facing = PI * 0.5


func _build_camera() -> void:
	cam = Camera2D.new()
	cam.name = "Camera"
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map.bounds.size.x if map.bounds.size.x > 0.0 else map.w * GeneratedMap.TILE)
	cam.limit_bottom = int(map.bounds.size.y if map.bounds.size.y > 0.0 else map.h * GeneratedMap.TILE)
	cam.position = local_actor.global_position if local_actor != null else map.world_size() * 0.5
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	var aspect := 1.777
	var vp := get_viewport()
	if vp != null:
		var vs := vp.get_visible_rect().size
		if vs.y > 1.0:
			aspect = vs.x / vs.y
	camera_zoom = clampf(aspect / 1.55, 0.78, 1.35)
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	zoom_aspect = camera_zoom
	add_child(cam)
	cam.make_current()


func _build_hud() -> void:
	hud = load("res://src/ui/match_hud.gd").new()
	hud.set("world", self)
	if hud.has_method("bind_player"):
		hud.call("bind_player", local_actor)
	add_child(hud)


func _build_mode(mode_id: String) -> void:
	var script_path := "res://src/modes/mode_%s.gd" % mode_id
	var script: Script = null
	if ResourceLoader.exists(script_path):
		script = load(script_path)
	if script == null:
		script = load("res://src/modes/mode_heist.gd")
	mode = script.new()
	mode.name = "Mode"
	mode.set("world", self)
	add_child(mode)
	if mode.has_method("start"):
		mode.call("start")


## Visual fog of war: a map-sized darkness sprite driven by a visibility mask.
func _build_fog_overlay() -> void:
	if str(cfg.get("fog", "on")) == "off":
		return
	fog = FogOverlay.new()
	fog.name = "FogOfWar"
	add_child(fog)
	fog.setup(map)
	fog.viewer_team = int(cfg.get("team", 0))
	fog.eye = local_actor
	_apply_fog_settings()


func _apply_fog_settings() -> void:
	if fog == null:
		return
	var cfg_video: Dictionary = GameFlow.profile.get("video", {})
	fog.set_enabled(bool(cfg_video.get("fog", true)))


## Post-processing stack: CRT/vignette above the world, below the HUD.
func _build_post_fx() -> void:
	var crt := CrtOverlay.new()
	add_child(crt)
	post_fx = crt


# ---------------------------------------------------------------------------
# NETWORK (see src/net/net_session.gd + net_codec.gd)
# ---------------------------------------------------------------------------

func _net_boot() -> void:
	net = NetSession.new()
	net.setup(self)
	NetLink.match_hook = net
	is_client = net.is_active and not net.is_host
	for a in actors:
		if a != null and a.is_bot:
			a.set_meta("peer", 0)
	if is_client:
		# clients do not run AI or objectives locally: the host is the authority
		spectator = false


## A client has no local simulation, but it still needs a camera and a HUD so the
## loading transition lands on something. Actors appear with the first snapshot.
func _build_offline_hud_shell() -> void:
	_build_camera()
	_build_hud()


## Client: an actor id we have never seen -> build it from the snapshot row.
func _spawn_net_actor(row: Dictionary) -> Actor:
	var node: Actor = null
	var peer := int(row.get("peer", 0))
	if peer != 0 and peer == NetLink.my_peer_id():
		node = ActorPlayer.new()
		local_actor = node as ActorPlayer
	else:
		node = Actor.new()
		node.is_bot = peer == 0
	node.configure(int(row.get("id", next_actor_id)), str(row.get("n", "БОЕЦ")), int(row.get("t", 0)), node.is_bot)
	next_actor_id = maxi(next_actor_id, node.a_id + 1)
	node.set_meta("peer", peer)
	node.skin_outfit = str(row.get("out", "heist"))
	if actors_root == null:
		return null
	actors_root.add_child(node)
	actors.append(node)
	node.world = self
	node.map = map
	node.set_outfit(node.skin_outfit)
	if node == local_actor:
		if hud != null:
			hud.call("bind_player", node)
	return node


## Client-only: regenerate the world from the host's seed/theme/mode.
func _rebuild_map_from_host(payload: Dictionary) -> void:
	var host_seed := int(payload.get("seed", 0))
	var host_theme := str(payload.get("theme", ""))
	var host_mode := str(payload.get("mode", str(cfg.get("mode", "heist"))))
	if host_seed == 0 or host_theme == "" or not Db.MAPS.has(host_theme):
		return
	if map != null and map.seed_value == host_seed and map.theme_id == host_theme:
		return
	cfg["seed"] = host_seed
	cfg["map"] = host_theme
	cfg["mode"] = host_mode
	rng.seed = host_seed
	map = MapGen.generate(host_theme, host_seed, host_mode)
	if visual != null:
		remove_child(visual)
		visual.queue_free()
		visual = null
	if effects != null:
		if effects.get_parent() != null:
			effects.get_parent().remove_child(effects)
		effects.queue_free()
		effects = null
	for d in doors:
		if d != null and is_instance_valid(d):
			if d.get_parent() != null:
				d.get_parent().remove_child(d)
			d.queue_free()
	doors.clear()
	for e in explosives:
		if e != null and is_instance_valid(e):
			if e.get_parent() != null:
				e.get_parent().remove_child(e)
			e.queue_free()
	explosives.clear()
	visual = MapVisual.new()
	visual.name = "MapVisual"
	add_child(visual)
	visual.setup(map)
	# the fresh map visual must sit under every other layer, right where it was
	if actors_root != null and actors_root.get_index() > 0:
		move_child(visual, 0)
	effects = Effects.new()
	effects.map = map
	if fx_root != null:
		fx_root.add_child(effects)
	_build_doors()
	_build_explosives()
	if fog != null:
		fog.setup(map)
	var mode_data: Dictionary = Db.MODES.get(host_mode, Db.MODES["heist"])
	police_delay = float(mode_data.get("police_delay", 180.0))
	Signals.notify.emit("Карта хоста загружена: %s" % str(map.theme.get("name", host_theme)), "info")


func actor_for_peer(peer: int) -> Actor:
	for a in actors:
		if a != null and int(a.get_meta("peer", 0)) == peer:
			return a
	return null


## Called on the client when the host ships the seed + roster.
##
## The client generated its own map from its own config when the scene loaded,
## so the first thing to do is throw that away and rebuild the exact same
## geometry the host is standing on. Without this every collision, door and
## sightline disagrees and the match desyncs on the first shot.
func on_net_roster(payload: Dictionary) -> void:
	roster = payload.get("roster", [])
	if bool(payload.get("has_map", false)):
		_rebuild_map_from_host(payload)
	for a in actors:
		if a != null and is_instance_valid(a):
			a.map = map
	for d in doors:
		if d != null and is_instance_valid(d) and d.has_method("rebind_map"):
			d.rebind_map(map)
	if not actors.is_empty():
		# already mirrored from snapshots: attach peer ids, keep the actors
		for row in roster:
			var actor := _find_actor(int(row.get("id", -1)))
			if actor != null:
				actor.set_meta("peer", int(row.get("peer", 0)))
		return
	for row in roster:
		if bool(row.get("bot", false)):
			continue
		var peer := int(row.get("peer", 1))
		var node: Actor = null
		if peer == NetLink.my_peer_id():
			node = ActorPlayer.new()
			(node as ActorPlayer).input_enabled = true
			local_actor = node as ActorPlayer
		else:
			node = Actor.new()
		node.a_id = int(row.get("id", next_actor_id))
		next_actor_id = maxi(next_actor_id, node.a_id + 1)
		node.a_name = str(row.get("n", "ИГРОК"))
		node.set_meta("peer", peer)
		node.team = int(row.get("t", Db.TEAM_CRIMINAL))
		node.is_bot = false
		node.skin_outfit = str(row.get("out", "heist"))
		actors.append(node)
		actors_root.add_child(node)
		if node.visual != null:
			node.visual.setup(node.team, node.skin_outfit)
		if node == local_actor:
			if cam != null:
				cam.position = node.global_position
			if hud != null:
				hud.call("bind_player", node)
	Signals.notify.emit("Подключено к хосту. Загрузка матча...", "success")


## Client: a full or diffed snapshot arrived.
func apply_snapshot(data: Dictionary) -> void:
	if not is_client:
		return
	elapsed = float(data.get("el", elapsed))
	if data.has("sc"):
		var sc: Array = data["sc"]
		team_score = {0: int(sc[0]), 1: int(sc[1])}
	if data.has("al"):
		var new_alarm := int(data["al"])
		if new_alarm != alarm_level:
			alarm_level = new_alarm
			Signals.alarm_changed.emit(alarm_level, "сеть")
	police_arrived = bool(int(data.get("pa", 1 if police_arrived else 0)))
	police_arrive_timer = float(data.get("pt", police_arrive_timer))
	if bool(data.get("full", false)):
		for a in actors:
			a.set_meta("net_seen", false)
	# roster arrives as a reliable side-channel: peers, names, outfits
	if data.has("r"):
		for row in data["r"]:
			var found := _find_actor(int(row.get("id", -1)))
			if found != null:
				found.set_meta("peer", int(row.get("peer", 0)))
	for row in data.get("a", []):
		var a := _find_actor(int(row.get("id", -1)))
		if a == null:
			a = _spawn_net_actor(row)
		if a == null:
			continue
		a.set_meta("net_seen", true)
		NetCodec.apply_actor(a, row)
	if is_instance_valid(local_actor):
		local_actor.is_local_player = true
		Sfx.listener_pos = local_actor.global_position
	for d in data.get("d", []):
		var door_id := int(d.get("id", -1))
		for door in doors:
			if door.door_id == door_id:
				door.open = bool(int(d.get("o", 0)))
				door.locked = bool(int(d.get("l", 0)))
				door.swing = float(d.get("s", 0.0))
				door.queue_redraw()
				break
	if data.has("o") and mode != null and mode.has_method("net_apply"):
		mode.call("net_apply", data["o"])


func _find_actor(id: int) -> Actor:
	for a in actors:
		if a != null and a.a_id == id:
			return a
	return null


## Host: replay a client's input packet on the authoritative actor.
func apply_net_input(a: Actor, packet: Dictionary) -> void:
	if a == null or a.dead:
		return
	a.move_dir = Vector2(float(packet.get("mx", 0.0)), float(packet.get("my", 0.0)))
	a.facing = float(packet.get("fa", a.facing))
	a.aiming = bool(int(packet.get("aim", 0)))
	a.sprinting = bool(int(packet.get("sp", 0)))
	a.crouching = bool(int(packet.get("cr", 0)))
	if bool(int(packet.get("fir", 0))):
		a.try_fire(a.global_position + Vector2(cos(a.facing), sin(a.facing)) * 240.0)
	if bool(int(packet.get("it", 0))) and a.interact_target != null:
		a.tick_interact(1.0 / 30.0, true)


## Host: replay a client's squad order.
func apply_net_order(a: Actor, packet: Dictionary) -> void:
	if a == null:
		return
	var pos := Vector2(float(packet.get("x", 0.0)), float(packet.get("y", 0.0)))
	var kind := str(packet.get("k", ""))
	give_order(a.a_id, kind, pos)
	Signals.bot_order.emit(a.a_id, kind)


func on_net_failure(reason: String) -> void:
	Signals.notify.emit("Сеть: " + reason + " — матч продолжается с ботами", "warning")
	is_client = false


## Client helper: send a squad order upstream instead of applying it locally.
func net_order(kind: String, pos: Vector2) -> void:
	if net != null:
		net.send_order(kind, pos)


func is_online() -> bool:
	return net != null and net.is_active


# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if paused:
		return
	_tick_timers(delta)
	if match_over:
		return
	elapsed += delta
	_drain_noise()
	if mode != null and mode.has_method("tick"):
		mode.call("tick", delta)
	_tick_police_arrival(delta)

	_tick_visibility(delta)
	_tick_drones(delta)
	_tick_minimap_cache()
	if fog != null:
		fog.eye = local_actor
	_tick_replay_buffer(delta)
	_check_stalemate()
	Sfx.listener_pos = cam.global_position if cam != null else Vector2.ZERO


func _process(delta: float) -> void:
	if net != null:
		net.tick(delta)
	if paused:
		return
	if is_client:
		_update_camera(delta)
		if hud != null and hud.has_method("tick"):
			hud.call("tick", delta)
		return
	_update_camera(delta)
	if hud != null and hud.has_method("tick"):
		hud.call("tick", delta)
	if match_over:
		return


func _drain_noise() -> void:
	if noise_events.is_empty():
		return
	var batch := noise_events.duplicate()
	noise_events.clear()
	for n in batch:
		last_noise_pos = n["pos"]
		last_noise_kind = n["kind"]
		for a in actors:
			if a.dead or a.ai == null:
				continue
			if a.team == int(n["team"]) and a.team != Db.TEAM_CIVILIAN:
				continue
			if a.ai.has_method("hear_noise"):
				a.ai.call("hear_noise", n["pos"], n["radius"], n["kind"])
			elif a.ai.has_method("hear_noise"):
				a.ai.call("hear_noise", n["pos"], n["radius"], n["kind"])


func _tick_police_arrival(delta: float) -> void:
	if police_arrived or police_arrive_timer < 0.0:
		return
	police_arrive_timer -= delta
	Signals.police_arrival.emit(police_arrive_timer)
	if police_arrive_timer <= 0.0:
		summon_police("время вышло")


func _tick_orders() -> void:
	for id in orders.keys():
		var a := _actor_by_id(int(id))
		if a == null or a.dead:
			continue
		if a.ai != null:
			var target: Vector2 = orders[id].get("target", Vector2.ZERO)
			a.ai.set("order", str(orders[id].get("kind", "follow")))
			if target != Vector2.ZERO:
				a.ai.set("order_target", target)


func _tick_visibility(delta: float) -> void:
	_vis_frame += 1
	_vis_accum += delta
	if _vis_accum < 0.1:
		return
	_vis_accum = 0.0
	var viewer_team := int(cfg.get("team", 0))
	if spectator:
		viewer_team = local_actor.team if local_actor != null else 0
	var new_vis := {}
	for a in actors:
		if a.team != viewer_team:
			continue
		if a.is_civilian:
			continue
		for e in actors:
			if e.team == viewer_team:
				continue
			var d := a.global_position.distance_to(e.global_position)
			var range_ := 1000.0 * (1.0 - e.concealment * 0.55)
			if d > range_:
				continue
			if _los_blocked(a.global_position, e.global_position):
				continue
			if _smoke_between(a.global_position, e.global_position):
				continue
			new_vis[e.a_id] = true
			last_known[e.a_id] = e.global_position
	for a in actors:
		if a.team == viewer_team:
			continue
		if a.dead:
			continue
		var visible := new_vis.has(a.a_id)
		var is_ally_civ := a.is_civilian
		if is_ally_civ:
			visible = true
		a.visible_to[viewer_team] = visible
	# local player + ally teammate vision always visible; enemies fogged
	for a in actors:
		if a.team == viewer_team:
			a.visual.modulate = Color.WHITE
		else:
			var can_see := bool(a.visible_to.get(viewer_team, false)) or a.dead
			if a.is_civilian and not can_see and local_actor != null:
				can_see = a.global_position.distance_to(local_actor.global_position) < 520.0
			a.visual.modulate.a = 1.0 if can_see else 0.0
	visible_enemies = new_vis


## Drones expand the team's vision: anything within their radius counts as
## spotted even without a friendly line of sight.
func _tick_drones(delta: float) -> void:
	if drones.is_empty():
		return
	var alive: Array[Dictionary] = []
	for d in drones:
		d["life"] = float(d["life"]) - delta
		if float(d["life"]) <= 0.0:
			continue
		alive.append(d)
		if int(d["team"]) != int(cfg.get("team", 0)):
			continue
		for e in actors:
			if e == null or e.dead or e.team == int(d["team"]):
				continue
			if e.global_position.distance_to(d["pos"]) < 420.0:
				visible_enemies[e.a_id] = true
	drones = alive


## Barricades: destroyed by gunfire, they unseal their tile. Damage arrives from
## bullets through impact_fx(kind="barricade").
func damage_barricade_at(pos: Vector2, amount: float) -> bool:
	for b in barricades:
		if (b["pos"] as Vector2).distance_to(pos) > 30.0:
			continue
		if amount <= 0.0:
			return true
		b["hp"] = float(b["hp"]) - amount
		if float(b["hp"]) <= 0.0:
			var cell: Vector2i = b["cell"]
			if map.tile_at(cell) == GeneratedMap.TK_CRATE:
				map.set_tile_cell(cell, GeneratedMap.TK_FLOOR)
				map.refresh_cell(cell)
				if visual != null:
					visual._build_physics_bounds()
			barricades.erase(b)
			Signals.match_event.emit("БАРРИКАДА РАЗБИТА", Color("ff1f4b"), "fortify")
		return true
	return false


func _tick_minimap_cache() -> void:
	minimap_snapshot.clear()
	for a in actors:
		if a == null or a.dead:
			continue
		minimap_snapshot.append({"p": a.global_position, "f": a.facing, "t": a.team, "civ": a.is_civilian, "id": a.a_id, "vis": false})
	minimap_corpses.clear()
	for c in corpses:
		if c != null:
			minimap_corpses.append({"p": c.global_position, "t": c.team})


func _check_stalemate() -> void:
	var mode_data: Dictionary = Db.MODES.get(str(cfg.get("mode", "")), {})
	var limit := int(mode_data.get("max_minutes", 0)) * 60
	if limit > 0 and elapsed > limit and not match_over:
		_finish_time_limit()


# ---------------------------------------------------------------------------
# COMBAT API (used by bullets, thrown objects, doors, actor code)
# ---------------------------------------------------------------------------

func actors_all() -> Array:
	return actors


func actors_for_team(team: int) -> Array:
	if team < 0:
		return actors
	var out: Array = []
	for a in actors:
		if a.team == team:
			out.append(a)
	return out


func actors_enemies_of(team: int) -> Array:
	var out: Array = []
	for a in actors:
		if a.team != team and a.team != Db.TEAM_CIVILIAN and not a.dead:
			out.append(a)
	return out


func actor_by_id(id: int) -> Actor:
	return _actor_by_id(id)


func _actor_by_id(id: int) -> Actor:
	for a in actors:
		if a.a_id == id:
			return a
	return null


func vision_blocked(from: Vector2, to: Vector2) -> bool:
	return _los_blocked(from, to)


func _los_blocked(from: Vector2, to: Vector2) -> bool:
	return not Util.los_clear_fast(map, from, to)


func _smoke_between(from: Vector2, to: Vector2) -> bool:
	if effects == null:
		return false
	if effects.fire_at(from.lerp(to, 0.5)):
		return true
	if effects.smoke_clouds.is_empty():
		return false
	return effects.smoke_on_line(from, to)


func light_at(pos: Vector2) -> float:
	if map == null:
		return 0.0
	var c := map.world_to_cell(pos)
	var light := 0.0
	for l in map.lights:
		var lp := map.cell_to_world(l["cell"])
		var radius := float(l.get("radius", 180.0))
		var d := lp.distance_to(pos)
		if d < radius:
			light += (1.0 - d / radius) * float(l.get("power", 1.0)) * 0.8
	# indoor rooms with lights off are dark
	var room_idx := map.room_at_cell(c)
	if room_idx >= 0 and not bool(map.rooms[room_idx].get("lights_on", true)):
		light = 0.0
	if map.tile_at(c) == GeneratedMap.TK_STREET:
		light = maxf(light, 0.25)
	return clampf(light, 0.0, 1.0)


func bullet_blocked(from: Vector2, to: Vector2) -> Variant:
	var steps := int(from.distance_to(to) / 12.0) + 1
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		var c := map.world_to_cell(p)
		var t := map.tile_at(c)
		if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_VOID or t == GeneratedMap.TK_CRATE:
			# doors can be shot through
			var di := map.door_at(c)
			if di >= 0 and t == GeneratedMap.TK_DOOR:
				pass
			else:
				# thin glass is penetrable
				if t == GeneratedMap.TK_WINDOW and randf() < 0.8:
					_break_window(c)
					continue
				return p
	return null


func _break_window(c: Vector2i) -> void:
	map.set_tile(c, GeneratedMap.TK_VOID)
	visual.queue_redraw()
	Sfx.play_at("ui_click", map.cell_to_world(c), -12.0, 0.5)
	Signals.noise_made.emit(map.cell_to_world(c), 700.0, "glass", Db.TEAM_CRIMINAL)


func impact_fx(pos: Vector2, normal: Vector2, kind: String) -> void:
	Signals.impact.emit(pos, normal, kind)
	if kind == "barricade":
		damage_barricade_at(pos, 12.0)
	if effects == null:
		return
	if kind == "flesh":
		effects.bleeds(pos, normal, 0.5)
	else:
		effects.sparks(pos, normal, "wall")
		effects.dust(pos, normal)
	if visual != null:
		visual.add_bullet_hole(pos, normal)


func blood_burst(pos: Vector2, dir: Vector2, amount: float) -> void:
	if effects != null:
		effects.bleeds(pos, dir, amount)
	Signals.blood_spray.emit(pos, dir, amount)
	if visual != null and Util.blood_multiplier() > 0.0:
		visual.add_blood(pos, dir, amount * Util.blood_multiplier())
	if rng.randf() < 0.3 * Util.blood_multiplier():
		Sfx.play_at("flesh", pos, -10.0, randf_range(0.9, 1.2))


func add_bullet_hole(pos: Vector2, normal: Vector2) -> void:
	if visual != null:
		visual.add_bullet_hole(pos, normal)


func hit_feedback(victim: Actor, dmg: float, headshot: bool, shooter: Actor) -> void:
	if shooter != null and shooter.is_local_player:
		Signals.hit_confirmed.emit(victim.hp <= 0.0, headshot, victim.team)
		if effects != null:
			effects.damage_number(victim.global_position, dmg, "head" if headshot else "body")
		if headshot:
			Sfx.ui("hover")
	if victim.is_local_player:
		Signals.camera_shake.emit(4.0 * Util.screen_shake_multiplier(), 0.16)
		if shooter != null:
			var ang := (shooter.global_position - victim.global_position).angle() - victim.facing
			Signals.damage_number.emit(shooter.global_position, 0.0, "dir:%f" % ang)


func spawn_hitscan(origin: Vector2, dir: Vector2, w: Dictionary, shooter: Actor, _unused: float) -> Node2D:
	var b := Bullet.new()
	b.world = self
	b.setup(origin, dir, w, shooter, float(w.get("speed", 4200.0)))
	fx_root.add_child(b)
	return b


func spawn_projectile(origin: Vector2, dir: Vector2, w: Dictionary, shooter: Actor, speed: float) -> Node2D:
	var b := Bullet.new()
	b.world = self
	b.setup(origin, dir, w, shooter, speed)
	fx_root.add_child(b)
	return b


func spawn_thrown(origin: Vector2, dir: Vector2, w: Dictionary, shooter: Actor, gadget_id: String) -> Node2D:
	var t := ThrownObject.new()
	t.world = self
	t.map = map
	t.setup(gadget_id, origin, dir, w, shooter, float(w.get("speed", 620.0)))
	fx_root.add_child(t)
	return t


## Fortify: a 400 HP barricade on the grid. Blocks bullets and walking until
## it is shot down, so it buys a corridor for a few seconds.
func deploy_barricade(pos: Vector2, team: int) -> void:
	var cell := map.world_to_cell(pos)
	if not map.walkable(cell):
		return
	map.set_tile_cell(cell, GeneratedMap.TK_CRATE)
	map.refresh_cell(cell)
	if visual != null:
		visual._build_physics_bounds()
	barricades.append({"cell": cell, "hp": 400.0, "team": team, "pos": pos})
	Signals.match_event.emit("БАРРИКАДА", Color("ffb02b"), "fortify")


## Breach kit: silently unlocks a door within arm's reach instead of kicking it.
func breach_kit_used(pos: Vector2, by: Actor) -> void:
	var best: Door = null
	var best_d := 90.0
	for d in doors:
		var dist := d.global_position.distance_to(pos)
		if dist < best_d:
			best_d = dist
			best = d
	if best == null:
		Signals.notify.emit("Ломать нечего: подойди к двери", "warning")
		return
	best.set_locked(false)
	Signals.notify.emit("Замок снят тихо", "good")
	if by != null:
		by.score += 20


## Drone: a hovering eye that reveals enemies near it for a while.
func deploy_drone(pos: Vector2, team: int, by: Actor) -> void:
	drones.append({"pos": pos, "team": team, "life": 25.0, "by": by.a_id if by != null else 0})
	Signals.match_event.emit("ДРОН В ВОЗДУХЕ", Color("35c9ff"), "drone")


func spawn_smoke(pos: Vector2, radius: float, seconds: float) -> void:
	if effects != null:
		effects.smoke(pos, radius, seconds)
	Sfx.play_at("shot_suppressed", pos, -10.0, 0.7)


func spawn_fire(pos: Vector2, seconds: float, radius: float) -> void:
	if effects != null:
		effects.fire(pos, radius, seconds)
	if visual != null:
		visual.add_scorch(pos, radius)
	Sfx.play_at("fire", pos, -8.0)


func flash_burst(pos: Vector2, seconds: float, radius: float, by_team: int, by_actor: Actor) -> void:
	if effects != null:
		effects.flash(pos, radius, Color(1, 1, 1, 0.9))
	Sfx.play_at("shot_flash", pos, 0.0)
	for a in actors:
		if a.dead or a.team == by_team:
			continue
		var d := a.global_position.distance_to(pos)
		if d > radius:
			continue
		var facing_towards := Util.cone_contains(a.global_position, a.facing, pos, 1.4)
		var mult := 1.0 if facing_towards else 0.45
		if not _los_blocked(pos, a.global_position):
			a.apply_flash(seconds * mult)
	Signals.camera_shake.emit(3.0, 0.3)


func explode(pos: Vector2, radius: float, damage: float, by: Actor, weapon_id: String) -> void:
	if effects != null:
		effects.explosion(pos, radius)
	if visual != null:
		visual.add_scorch(pos, radius)
	if cam != null:
		var d := cam.global_position.distance_to(pos)
		Signals.camera_shake.emit(clampf(22.0 - d / 60.0, 2.0, 20.0) * Util.screen_shake_multiplier(), 0.45)
	Sfx.play_at("explosion", pos, 2.0, randf_range(0.9, 1.1))
	Sfx.play_at("explosion", pos + Vector2(30, 0), -6.0, 0.7)
	Signals.noise_made.emit(pos, 2400.0, "explosion", by.team if by != null else 2)
	for a in actors:
		if a.dead:
			continue
		var d := a.global_position.distance_to(pos)
		if d > radius:
			continue
		if _los_blocked(pos, a.global_position) and d > radius * 0.4:
			continue
		var falloff := 1.0 - clampf(d / radius, 0.0, 1.0)
		var dmg := damage * (0.35 + falloff * 0.9)
		a.take_damage(dmg, by, "explosion", (a.global_position - pos).normalized(), false)
		if a.downed:
			a.hp = maxf(a.hp, 0.0)
	# chain reactions
	for e in explosives:
		if e.exploded:
			continue
		if e.global_position.distance_to(pos) < radius * 1.05:
			e.chain_timer += 0.001
			var t := get_tree().create_timer(randf_range(0.15, 0.5))
			t.timeout.connect(e.explode)
	# break nearby doors
	for d2 in doors:
		if d2.global_position.distance_to(pos) < radius * 0.8 and d2.hp > 0.0:
			d2.hp -= damage * 0.5
			if d2.hp <= 0.0:
				d2.breach()
	if by != null:
		by.kills += 0


func muzzle_light(pos: Vector2, loud: bool) -> void:
	if visual != null and visual.lights_layer != null:
		visual.lights_layer.call("flash", pos, Color(1.0, 0.9, 0.6), 0.1 if loud else 0.05)


func rocket_smoke(pos: Vector2, dir: Vector2) -> void:
	if effects != null:
		effects.dust(pos, -dir)


func stun_cone(pos: Vector2, radius: float, seconds: float, by_team: int) -> void:
	for a in actors:
		if a.dead or a.team == by_team:
			continue
		if a.global_position.distance_to(pos) < radius:
			a.apply_stun(seconds)


func door_breached(door: Door) -> void:
	Signals.door_state.emit(door.door_id, true, false)
	if mode != null and mode.has_method("on_door_breached"):
		mode.call("on_door_breached", door)
	raise_alarm(1, "взлом двери")


## Scavenger perk: reserve ammo picked from a corpse is 50% bigger.
func ammo_from_corpse(by: Actor, base_amount: int) -> int:
	return int(float(base_amount) * Perks.ammo_pickup_mult(by))


func drop_weapon(pos: Vector2, weapon_id: String, mag: int, reserve: int) -> void:
	var pickup := WeaponPickup.new()
	pickup.weapon_id = weapon_id
	pickup.mag = mag
	pickup.reserve = reserve
	pickup.global_position = pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
	pickup.world = self
	pickup.z_index = 3
	fx_root.add_child(pickup)


func drop_bag(pos: Vector2, carrier_id: int) -> void:
	var bag := ObjectiveNode.new()
	bag.setup(ObjectiveNode.Kind.CASH, pos, "СУМКА", self, Color("ffb02b"))
	bag.data["carrier"] = carrier_id
	bag.radius = 46.0
	add_child(bag)
	bags.append(bag)
	Signals.bag_dropped.emit(pos, carrier_id)
	Signals.notify.emit("Сумка выпала. Кто-то должен её поднять.", "warning")
	for a in actors:
		if a.team == Db.TEAM_CRIMINAL and not a.dead and a.global_position.distance_to(pos) < 60.0:
			a.bag_carried = true
			a.visual.carrying_bag = true
			bag.queue_free()
			bags.erase(bag)
			return


func visible_corpses(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	for c in corpses:
		if pos.distance_to(c.global_position) < radius:
			out.append(c)
	return out


func nearby_civilians(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	for a in actors:
		if a.is_civilian and not a.dead and a.global_position.distance_to(pos) < radius:
			out.append(a)
	return out


func share_contact(team: int, pos: Vector2, enemy_id: int) -> void:
	last_known[enemy_id] = pos
	for a in actors:
		if a.team != team or a.dead or a.ai == null:
			continue
		if a.global_position.distance_to(pos) < 900.0:
			a.ai.set("investigate_point", pos)
			a.ai.set("investigate_time", 4.0)


func on_civilian_call(pos: Vector2) -> void:
	raise_alarm(2, "гражданский вызвал полицию")
	if police_arrive_timer > 45.0 or police_arrive_timer < 0.0:
		police_arrive_timer = minf(police_delay, 45.0) if police_arrive_timer > 0.0 else 45.0
	if mode != null and mode.has_method("on_alarm"):
		mode.call("on_alarm", 2)


## Nearest downed teammate within reach.
func _find_downed_ally(a: Actor) -> Actor:
	if a.is_civilian or a.dead:
		return null
	var best: Actor = null
	var best_d := 70.0
	for m in actors:
		if m == null or m == a or not m.downed or m.dead:
			continue
		if m.team != a.team:
			continue
		var d := m.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


## Actor.tick_interact -> downed teammate.interact()
func revive_ally(by: Actor, fallen: Actor) -> void:
	if by == null or fallen == null or not fallen.downed:
		return
	fallen.revive(by)
	by.score += 60
	Signals.match_event.emit("ПОДНЯТ: %s" % fallen.a_name, Color("2bff9a"), "revive")


## Nearest civilian this actor can grab or release (hostage escort, witness
## escort). Returns null when there is nothing within arm's reach.
func _find_grabbable(a: Actor) -> Variant:
	if a.team == Db.TEAM_CIVILIAN or a.dead:
		return null
	# already escorting someone -> offer release
	if a.get_meta("escort_id", 0) != 0:
		var cur: Actor = _actor_by_id(int(a.get_meta("escort_id", 0)))
		if cur != null and not cur.dead:
			return {"node": cur, "kind": "release_hostage", "text": "Отпустить [E]", "time": 0.5}
		a.set_meta("escort_id", 0)
	var best: Actor = null
	var best_d := 62.0
	for c in actors:
		if c == null or c.is_civilian == false or c.dead:
			continue
		if c.get_meta("rescued", false):
			continue
		if c.get_meta("escort_id", 0) != 0:
			continue
		var d := c.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return null
	var is_held := bool(best.get_meta("hostage", false))
	if is_held:
		return {"node": best, "kind": "grab_hostage", "text": "Взять заложника [E]", "time": 1.1}
	if best.downed or best.get_meta("surrender", false) or a.team == Db.TEAM_POLICE:
		return {"node": best, "kind": "arrest_civilian", "text": "Задержать [E]", "time": 1.4}
	return null


## Called by Actor.tick_interact -> CivActor.interact().
func grab_civilian(by: Actor, civil: Actor, as_hostage: bool) -> void:
	if by == null or civil == null or civil.dead:
		return
	by.set_meta("escort_id", civil.a_id)
	civil.set_meta("escort_id", by.a_id)
	if civil.ai != null and civil.ai.has_method("be_grabbed"):
		civil.ai.call("be_grabbed", by, true)
	if as_hostage:
		civil.set_meta("hostage", true)
		civil.set_meta("hostage_state", "held")
		Signals.hostage_state.emit(civil.a_id, "held")
		Signals.match_event.emit("ЗАЛОЖНИК ВЗЯТ", Color("ff2bd6"), "hostage")
	else:
		Signals.match_event.emit("ГРАЖДАНСКИЙ ЗАДЕРЖАН", Color("35c9ff"), "arrest")
	by.score += 25


func release_civilian(by: Actor, civil: Actor) -> void:
	if civil == null:
		return
	civil.set_meta("escort_id", 0)
	if by != null:
		by.set_meta("escort_id", 0)
	if civil.ai != null and civil.ai.has_method("release"):
		civil.ai.call("release")
	Signals.hostage_state.emit(civil.a_id, "released")


## Friendly fire is a match setting: modes like deathmatch keep it off so teams
## stay readable, custom lobbies can turn it on (and every damage path honours it).
func friendly_fire_enabled() -> bool:
	return bool(cfg.get("friendly_fire", friendly_fire))


func raise_alarm(level: int, reason: String) -> void:
	if level <= alarm_level:
		return
	alarm_level = level
	alarm_reason = reason
	Signals.alarm_changed.emit(level, reason)
	if visual != null and visual.lights_layer != null:
		visual.lights_layer.call("set_alarm", level)
	var text := "ТИХО" if level == 0 else ("ТРЕВОГА" if level >= 2 else "ПОДОЗРЕНИЕ")
	Signals.match_event.emit("%s: %s" % [text, reason], Color("ff2b62") if level >= 2 else Color("ffb02b"), "alarm")
	# music escalates with the alarm: the heist groove gives way to a chase
	var arcade := str(Db.MODES.get(str(cfg.get("mode", "")), {}).get("family", "")) == "arcade"
	if not arcade:
		if level >= 2:
			Sfx.play_music("tension", 2.5)
		elif level == 0:
			Sfx.play_music("heist", 3.0)
	if level >= 2:
		Sfx.play_ui("alarm")
	if level >= 2:
		Sfx.play_at("alarm", (local_actor.global_position if local_actor != null else Vector2.ZERO), -6.0)
		if police_arrive_timer > 60.0 or police_arrive_timer < 0.0:
			police_arrive_timer = 60.0
		if mode != null and mode.has_method("on_alarm"):
			mode.call("on_alarm", 2)
	elif level == 1 and mode != null and mode.has_method("on_alarm"):
		mode.call("on_alarm", 1)


func summon_police(reason: String) -> void:
	if police_arrived:
		return
	police_arrived = true
	police_arrive_timer = 0.0
	Signals.match_event.emit("ПОЛИЦИЯ НА МЕСТЕ: %s" % reason, Color("35c9ff"), "police")
	raise_alarm(2, "прибыла полиция")
	var team := Db.TEAM_POLICE
	var mode_data: Dictionary = Db.MODES.get(str(cfg.get("mode", "")), Db.MODES["heist"])
	# spawn a police wave at the street entrance
	for i in range(4):
		if _count_team(Db.TEAM_POLICE) >= 8:
			break
		var outfit := _outfit_for(mode_data, Db.TEAM_POLICE, str(mode_data.get("family", "heist")))
		var b := _spawn_bot(Db.TEAM_POLICE, mode_data, outfit, int(cfg.get("difficulty", 1)), i + 30)
		b.ai.set("order", "advance")
		_place_actor(b, Db.TEAM_POLICE, false, i)
		Signals.notify.emit("Прибыло подкрепление: %s" % b.a_name, "warning")
	if visual != null and visual.lights_layer != null:
		for i in range(6):
			visual.lights_layer.call("beacon", local_actor.global_position + Vector2(rng.randf_range(-400, 400), -700), 3.0)


func _count_team(team: int) -> int:
	var n := 0
	for a in actors:
		if a.team == team and not a.dead:
			n += 1
	return n


func on_actor_died(victim: Actor, killer: Actor, headshot: bool, bled_out: bool) -> void:
	corpses.append(victim)
	var weapon_id := killer.current_weapon if killer != null else ""
	var tags: Array = []
	if headshot:
		tags.append("headshot")
	if bled_out:
		tags.append("bled_out")
	if killer != null and killer == victim:
		tags.append("suicide")
	if victim.is_civilian:
		tags.append("civilian")
		Signals.match_event.emit("ГРАЖДАНСКИЙ %s УБИТ" % victim.a_name, Color("ff2b62"), "civ")
		record_civilian_death(killer)
	else:
		if killer != null and killer != victim:
			# predator: a knife kill from behind patches the killer up
			if killer.current_weapon in ["knife", "machete", "katana"] and Perks.has(killer, "predator"):
				var back := absf(wrapf((victim.global_position - killer.global_position).angle() - victim.facing, -PI, PI)) < 1.1
				if back:
					killer.hp = minf(killer.max_hp, killer.hp + Perks.backstab_heal())
					Signals.match_event.emit("ХИЩНИК: +%d HP" % int(Perks.backstab_heal()), Color("2bff9a"), "perk")
			killer.kills += 1
			killer.kill_streak += 1
			killer.score += 100 + (50 if headshot else 0)
			killer.money += 150 if victim.team != killer.team else 0
			if headshot:
				killer.headshots += 1
			if killer.is_local_player:
				Sfx.ui("kill")
				Signals.match_event.emit("УБИЙСТВО%s" % (" В ГОЛОВУ" if headshot else ""), Color("b6ff2b"), "kill")
		Signals.actor_died.emit(victim.a_id, killer.a_id if killer != null else 0, weapon_id, headshot, tags)
	_push_killfeed(victim, killer, weapon_id, headshot)
	_capture_kill_clip(victim, killer, headshot)
	if mode != null and mode.has_method("on_actor_died"):
		mode.call("on_actor_died", victim, killer, headshot)
	# allies notice the body
	for a in actors:
		if a.dead or a.ai == null or a.team == victim.team:
			continue
		if a.global_position.distance_to(victim.global_position) < 340.0:
			if a.ai.has_method("see_corpse"):
				a.ai.call("see_corpse", victim.global_position)
	if victim == possessed:
		possession_follow_camera()
	if victim == local_actor and not victim.is_civilian:
		_on_player_died()
	_check_team_wipe()


func record_civilian_death(killer: Actor) -> void:
	if killer == null:
		return
	var family := str(Db.MODES.get(str(cfg.get("mode", "")), {}).get("family", ""))
	if killer.team == Db.TEAM_CRIMINAL:
		if family == "heist":
			raise_alarm(2, "убит гражданский")
		team_score[Db.TEAM_POLICE] += 1
	elif killer.team == Db.TEAM_POLICE:
		killer.money -= 500
		Signals.notify.emit("Штраф за гражданского: -$500", "bad")
		if hud != null:
			hud.call("flash_bad", "ГРАЖДАНСКИЙ УБИТ")


func _check_team_wipe() -> void:
	if match_over:
		return
	var crim_alive := 0
	var pol_alive := 0
	for a in actors:
		if a.dead or a.is_civilian:
			continue
		if a.team == Db.TEAM_CRIMINAL:
			crim_alive += 1
		else:
			pol_alive += 1
	if mode != null and mode.has_method("on_team_counts"):
		mode.call("on_team_counts", crim_alive, pol_alive)
	if crim_alive == 0 and str(Db.MODES.get(str(cfg.get("mode", "")), {}).get("family", "")) != "arcade":
		if mode != null and mode.has_method("team_eliminated"):
			mode.call("team_eliminated", Db.TEAM_CRIMINAL)
	if pol_alive == 0 and str(Db.MODES.get(str(cfg.get("mode", "")), {}).get("family", "")) != "arcade":
		if mode != null and mode.has_method("team_eliminated"):
			mode.call("team_eliminated", Db.TEAM_POLICE)


func _push_killfeed(victim: Actor, killer: Actor, weapon_id: String, headshot: bool) -> void:
	var entry := {
		"killer": killer.a_name if killer != null else "МИР",
		"killer_team": killer.team if killer != null else 2,
		"victim": victim.a_name, "victim_team": victim.team,
		"weapon": weapon_id, "headshot": headshot, "civ": victim.is_civilian,
		"time": elapsed,
	}
	killfeed.append(entry)
	if killfeed.size() > 8:
		killfeed.pop_front()
	Signals.killfeed.emit(entry)


# ---------------------------------------------------------------------------
# REPLAY / HIGHLIGHT CAPTURE
# ---------------------------------------------------------------------------

func _setup_replay_buffer() -> void:
	clip_buffer.clear()
	best_clip = {}
	replays.clear()


func _tick_replay_buffer(delta: float) -> void:
	clip_accum += delta
	if clip_accum < 1.0 / CLIP_HZ:
		return
	clip_accum = 0.0
	var frame := {"t": elapsed, "a": []}
	for a in actors:
		if a.is_civilian and a.dead:
			continue
		frame["a"].append([a.a_id, a.global_position.x, a.global_position.y, a.facing, a.current_weapon, 1 if a.dead else 0, a.team, a.skin_outfit, a.a_name])
	clip_buffer.append(frame)
	while clip_buffer.size() > MAX_CLIP_FRAMES:
		clip_buffer.pop_front()


func _capture_kill_clip(victim: Actor, killer: Actor, headshot: bool) -> void:
	if killer == null or victim.team == killer.team:
		return
	# multi-kill detection: kills within 3 seconds by the same killer
	recent_kills.append({"t": elapsed, "killer": killer.a_id})
	var window_start := elapsed - 3.0
	var streak := 0
	for k in recent_kills:
		if float(k["t"]) >= window_start and int(k["killer"]) == killer.a_id:
			streak += 1
	recent_kills = recent_kills.filter(func(k): return float(k["t"]) >= window_start)
	var label := ReplaySystem.streak_label(streak, headshot)
	var trimmed := ReplaySystem.window_around(clip_buffer, elapsed)
	var clip := ReplaySystem.make_clip(trimmed, killer, victim, streak, headshot, label)
	clip["map"] = map.theme_id
	clip["seed"] = map.seed_value
	if killer == local_actor:
		clip["score"] = int(clip["score"]) + 300
	replays.append(clip)
	if replays.size() > 12:
		replays.pop_front()
	if best_clip.is_empty() or int(clip["score"]) > int(best_clip.get("score", 0)):
		best_clip = clip
	Signals.replay_ready.emit(clip)
	if streak >= 3:
		Signals.match_event.emit(label, Color("ff2bd6"), "replay")


# ---------------------------------------------------------------------------
# ORDERS / POSSESSION
# ---------------------------------------------------------------------------

func give_order(bot_id: int, kind: String, target: Vector2 = Vector2.ZERO) -> void:
	orders[bot_id] = {"kind": kind, "target": target}
	var b := _actor_by_id(bot_id)
	if b == null:
		return
	if b.ai != null:
		b.ai.set_order(kind, target)
	var labels := {
		"follow": "СЛЕДУЙ", "hold": "ДЕРЖИ", "advance": "ВПЕРЁД",
		"flank": "ОБХОДИ", "retreat": "ОТСТУПАЙ", "revive": "ПОДНИМИ",
	}
	Signals.notify.emit("%s: %s" % [b.a_name, labels.get(kind, kind)], "info")


func order_all(kind: String) -> void:
	if is_client:
		net_order(kind, get_global_mouse_position())
		return
	for a in actors:
		if a.team == int(cfg.get("team", 0)) and a.is_bot and not a.is_civilian and not a.dead:
			give_order(a.a_id, kind)


## Comms perk: pings from a comms carrier mark enemies for longer. The marker
## itself lives in last_known, which the minimap reads.
func ping_mark(pos: Vector2, by: Actor) -> void:
	var radius := 420.0
	var extra := Perks.ping_duration_bonus(by)
	for e in actors:
		if e == null or e.dead or by == null or e.team == by.team:
			continue
		if e.global_position.distance_to(pos) < radius:
			last_known[e.a_id] = e.global_position
			if extra > 0.0:
				e.set_meta("pinged_until", elapsed + 4.0 + extra)


func order_click(pos: Vector2) -> void:
	var best: Actor = null
	var best_d := 99999.0
	for a in actors:
		if a.team != int(cfg.get("team", 0)) or a.is_civilian or a.dead:
			continue
		if not a.is_bot and a != possessed:
			continue
		var d := a.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = a
	if best == null or best_d > 320.0:
		return
	var kind := "advance"
	if Input.is_key_pressed(KEY_SHIFT):
		kind = "hold"
	elif Input.is_key_pressed(KEY_ALT):
		kind = "flank"
	give_order(best.a_id, kind, pos)
	ping_mark(pos, local_actor)
	Signals.ui_ping.emit(pos, kind)


func possession_follow_camera() -> void:
	if hud != null and hud.has_method("show_possession_prompt"):
		hud.call("show_possession_prompt")
	Signals.possession_targets.emit(possession_candidates())


## Living bot teammates the dead player may jump into, nearest first.
func possession_candidates() -> Array:
	var out: Array = []
	var team := int(cfg.get("team", 0))
	var origin := local_actor.global_position if is_instance_valid(local_actor) else Vector2.ZERO
	for a in actors:
		if a == null or a.is_civilian or a.dead or a.team != team or not a.is_bot:
			continue
		out.append(a)
	out.sort_custom(func(x, y): return x.global_position.distance_to(origin) < y.global_position.distance_to(origin))
	return out


func possess(actor_id: int) -> void:
	var target := _actor_by_id(actor_id)
	if target == null or target.dead or target.is_civilian:
		return
	if target.team != int(cfg.get("team", 0)):
		return
	if target is ActorPlayer:
		return
	var old := local_actor
	possessed = target
	target.is_local_player = false
	# turn the bot into a player-controlled actor: reuse ActorPlayer input path
	var p := ActorPlayer.new()
	p.a_id = target.a_id
	p.a_name = target.a_name
	p.team = target.team
	p.loadout = target.loadout
	p.gadget_charges = target.gadget_charges
	p.money = target.money
	p.kills = target.kills
	p.map = map
	p.world = self
	p.global_position = target.global_position
	p.facing = target.facing
	p.skin_outfit = target.skin_outfit
	p.max_hp = target.max_hp
	p.hp = maxf(target.hp, 45.0)
	p.armor = target.armor
	p.max_armor = target.max_armor
	p.revived_count = target.revived_count
	actors_root.add_child(p)
	p.setup_stats()
	p.hp = maxf(target.hp, 45.0)
	p.set_outfit(target.skin_outfit)
	p.equip_weapon(target.current_weapon)
	p.gadget_charges = target.gadget_charges
	p.is_local_player = true
	# remove the bot
	if target.ai != null:
		target.ai.queue_free()
		target.ai = null
	target.queue_free()
	actors.erase(target)
	actors.append(p)
	local_actor.queue_free()
	actors.erase(old)
	local_actor = p
	local_actor.visual.is_bot = false
	if hud != null:
		hud.set("world", self)
	if hud.has_method("bind_player"):
		hud.call("bind_player", local_actor)
	player_possessions_left -= 1
	Signals.match_event.emit("ВСЕЛЕНИЕ: %s" % p.a_name, Color("2bff9a"), "possession")
	if mode != null and mode.has_method("on_possess"):
		mode.call("on_possess", p)


func _on_player_died() -> void:
	possession_follow_camera()
	Signals.match_event.emit("ТЫ УБИТ", Color("ff1f4b"), "death")


# ---------------------------------------------------------------------------
# MODE HELPERS
# ---------------------------------------------------------------------------

func bot_objective_point(a: Actor) -> Variant:
	if mode != null and mode.has_method("bot_point"):
		return mode.call("bot_point", a)
	return null


func bot_retreat_point(a: Actor) -> Variant:
	if mode != null and mode.has_method("retreat_point"):
		return mode.call("retreat_point", a)
	return null


func find_interactable(a: Actor) -> Variant:
	var best: Variant = null
	if mode != null and mode.has_method("find_interactable"):
		best = mode.call("find_interactable", a)
	if best != null:
		return best
	# doors: the most-used interaction in the game
	var best_door: Door = null
	var best_d := 78.0
	for d in doors:
		var dist := d.global_position.distance_to(a.global_position)
		if dist < best_d:
			best_d = dist
			best_door = d
	# downed ally first: reviving is the most time-critical interaction
	var fallen := _find_downed_ally(a)
	if fallen != null:
		var speed := Perks.revive_speed_mult(a)
		return {"node": fallen, "kind": "revive", "text": "Поднять [E]", "time": 2.6 / speed}
	# hostages / witnesses: grab a civilian who already has their hands up
	var grab := _find_grabbable(a)
	if grab != null:
		return grab
	if best_door != null:
		if best_door.locked:
			if a.loadout.has("ksg") or a.loadout.has("breach_kit") or a.team == Db.TEAM_POLICE:
				var kick_time := 1.2 / Perks.interact_speed_mult(a)
				return {"node": best_door, "kind": "breach_door", "text": "Выбить дверь [E]", "time": kick_time}
			return {"node": best_door, "kind": "locked_door", "text": "Заперто", "time": 0.6}
		return {"node": best_door, "kind": "door", "text": "Открыть/закрыть [E]", "time": 0.2}
	return null


func finish_match(winner_team: int, reason: String, extra: Dictionary = {}) -> void:
	if match_over:
		return
	match_over = true
	var summary := {
		"winner": winner_team,
		"reason": reason,
		"mode": str(cfg.get("mode", "")),
		"map": map.theme_id,
		"seed": map.seed_value,
		"time": elapsed,
		"score": team_score.duplicate(),
		"replay": best_clip,
		"replays": replays.duplicate(true),
		"player": _player_stats(),
		"scoreboard": scoreboard_rows_data(),
		"extra": extra,
	}
	GameFlow.last_summary = summary
	if winner_team == int(cfg.get("team", 0)):
		GameFlow.add_cash(2200 + int(elapsed) * 6)
		GameFlow.add_xp(600)
		Signals.match_event.emit("ПОБЕДА", Color("2bff9a"), "end")
	else:
		GameFlow.add_cash(700)
		GameFlow.add_xp(220)
		Signals.match_event.emit("ПОРАЖЕНИЕ", Color("ff1f4b"), "end")
	GameFlow.record_stat("matches")
	var pl: Dictionary = summary["player"]
	GameFlow.record_stat("kills", int(pl.get("kills", 0)))
	GameFlow.record_stat("deaths", int(pl.get("deaths", 0)))
	GameFlow.record_stat("headshots", int(pl.get("headshots", 0)))
	if str(cfg.get("mode", "")) in ["heist", "siege", "bomb_defuse", "sabotage", "extraction", "vip"] and winner_team == int(cfg.get("team", 0)):
		GameFlow.record_stat("heists")
	GameFlow.save_profile()
	Sfx.play_music("menu", 2.0)
	Sfx.stop_ambience()
	Signals.match_ended.emit(summary)
	if hud != null and hud.has_method("show_end"):
		hud.call("show_end", summary)


func _finish_time_limit() -> void:
	var winner := 0
	if int(team_score.get(1, 0)) > int(team_score.get(0, 0)):
		winner = 1
	finish_match(winner, "время вышло")


func _player_stats() -> Dictionary:
	var p := local_actor
	return {
		"name": p.a_name if p != null else "?",
		"kills": p.kills if p != null else 0,
		"deaths": p.deaths if p != null else 0,
		"assists": p.assists if p != null else 0,
		"headshots": p.headshots if p != null else 0,
		"money": p.money if p != null else 0,
		"score": p.score if p != null else 0,
		"possessed": possessed != null,
	}


func scoreboard_rows_data() -> Array:
	var rows: Array = []
	for a in actors:
		if a.is_civilian:
			continue
		rows.append({
			"id": a.a_id, "name": a.a_name, "team": a.team, "kills": a.kills,
			"deaths": a.deaths, "score": a.score, "bot": a.is_bot, "money": a.money,
			"alive": not a.dead,
		})
	rows.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return rows


func respawn_actor(a: Actor) -> void:
	if a == null or a.is_civilian:
		return
	a.dead = false
	a.downed = false
	a.hp = a.max_hp
	a.armor = a.max_armor
	a.bleed = 0.0
	a.visual.dead = false
	a.visual.queue_redraw()
	a.collision_layer = 2
	a.collision_mask = 1 | 8
	_place_actor(a, a.team, a.is_local_player, rng.randi_range(0, 10))
	a.revived_count = 0
	if a.is_local_player and cam != null:
		cam.global_position = a.global_position


func _update_camera(delta: float) -> void:
	if cam == null:
		return
	var focus := local_actor.global_position if local_actor != null else map.world_size() * 0.5
	if local_actor != null and local_actor.dead:
		focus = local_actor.global_position
	var mouse := get_global_mouse_position()
	var look := (mouse - focus) * 0.16
	look = look.limit_length(160.0)
	var target_pos := focus + look
	if local_actor != null and local_actor.aiming:
		target_zoom = zoom_aspect * 1.14
	elif local_actor != null and local_actor.sprinting:
		target_zoom = zoom_aspect * 0.92
	else:
		target_zoom = zoom_aspect
	if local_actor != null and local_actor.current_weapon == "svd" and local_actor.aiming:
		target_zoom = zoom_aspect * 1.4
	camera_zoom = lerpf(camera_zoom, target_zoom, delta * 6.0)
	cam.zoom = Vector2(camera_zoom, camera_zoom)
	shake = maxf(0.0, shake - delta * 30.0)
	shake_time = maxf(0.0, shake_time - delta)
	var offset := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	cam.global_position = target_pos + offset


func _on_cam_shake(strength: float, seconds: float) -> void:
	shake = maxf(shake, strength)
	shake_time = maxf(shake_time, seconds)


func _on_noise(pos: Vector2, radius: float, kind: String, team: int) -> void:
	noise_events.append({"pos": pos, "radius": radius, "kind": kind, "team": team})
	if noise_events.size() > 32:
		noise_events.pop_front()


# ---------------------------------------------------------------------------
# TIMERS / GLOBAL SIGNALS
# ---------------------------------------------------------------------------

var _pending_timers: Array[Dictionary] = []


func schedule(delay: float, callback: Callable) -> void:
	_pending_timers.append({"t": delay, "cb": callback})


func _tick_timers(delta: float) -> void:
	if _pending_timers.is_empty():
		return
	var keep: Array[Dictionary] = []
	for t in _pending_timers:
		t["t"] = float(t["t"]) - delta
		if float(t["t"]) <= 0.0:
			var cb: Callable = t["cb"]
			if cb.is_valid():
				cb.call()
		else:
			keep.append(t)
	_pending_timers = keep


func _enter_tree() -> void:
	Signals.camera_shake.connect(_on_cam_shake)
	Signals.noise_made.connect(_on_noise)
	Signals.notify.connect(_on_notify)


func _exit_tree() -> void:
	if Signals.camera_shake.is_connected(_on_cam_shake):
		Signals.camera_shake.disconnect(_on_cam_shake)
	if Signals.noise_made.is_connected(_on_noise):
		Signals.noise_made.disconnect(_on_noise)
	if Signals.notify.is_connected(_on_notify):
		Signals.notify.disconnect(_on_notify)


func _on_notify(_text: String, _kind: String) -> void:
	pass


func _process_input() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if match_over:
		return
	if event.is_action_pressed("pause"):
		if hud != null and hud.has_method("toggle_pause"):
			hud.call("toggle_pause")
		return
	if event.is_action_pressed("scoreboard"):
		if hud != null and hud.has_method("set_scoreboard"):
			hud.call("set_scoreboard", true)
		return
	if event.is_action_released("scoreboard"):
		if hud != null and hud.has_method("set_scoreboard"):
			hud.call("set_scoreboard", false)
		return
	if event.is_action_pressed("buy"):
		if hud != null and hud.has_method("toggle_buy"):
			hud.call("toggle_buy")
		return
	if event.is_action_pressed("possess"):
		try_possession()
		return
	if event.is_action_pressed("command"):
		if hud != null and hud.has_method("open_command_wheel"):
			hud.call("open_command_wheel")
		return
	if event.is_action_pressed("ping"):
		order_click(get_global_mouse_position())
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4] and local_actor != null and not local_actor.dead:
			var idx := event.keycode - KEY_1
			if idx < local_actor.loadout.size():
				local_actor.switch_to(local_actor.loadout[idx])
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and hud != null and hud.has_method("is_command_wheel_open") and bool(hud.call("is_command_wheel_open")):
			hud.call("command_at", get_global_mouse_position())


func try_possession() -> void:
	if local_actor == null or not local_actor.dead:
		if local_actor != null and not local_actor.dead:
			Signals.notify.emit("Вселяться можно только после смерти", "warning")
		return
	if player_possessions_left <= 0:
		Signals.notify.emit("Вселения закончились", "bad")
		return
	# pick nearest living teammate bot
	var best: Actor = null
	var best_d := 1e9
	for a in actors:
		if a.is_civilian or a.dead or a.team != int(cfg.get("team", 0)):
			continue
		if not a.is_bot:
			continue
		var d := a.global_position.distance_to(local_actor.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		Signals.notify.emit("Вселяться не в кого", "bad")
		return
	possess(best.a_id)


func _on_key_held() -> void:
	pass
