extends SceneTree
## Headless smoke test: boots the game, starts a bot match, steps frames and
## verifies core invariants (map connectivity, bots, HUD, shooting).
##
## Run with:  ASH_AUTOTEST=1 godot --headless --path . --script res://tools/autotest.gd

var frames := 0
var phase := 0
var failures: Array = []
var main: Node = null
var match_node: null
var checked := {}


func _initialize() -> void:
	TestEnv.ensure_autoloads(root)
	var main_scene: Variant = load("res://scenes/Main.tscn")
	if main_scene == null:
		_fail("Main.tscn failed to load")
		_finish()
		return
	main = main_scene.instantiate()
	root.add_child(main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	frames += 1
	if main == null:
		return
	match phase:
		0:
			if frames > 40:
				if main.current == null:
					_fail("main menu not shown")
				phase = 1
		1:
			main.start_training()
			phase = 2
		2:
			match_node = main.match_node
			if match_node == null:
				if frames > 200:
					_fail("match did not start")
					_finish()
				return
			phase = 3
		3:
			_check_match()
			if frames > 1200:
				_finish()


func _fail(message: String) -> void:
	if failures.has(message):
		return
	failures.append(message)
	printerr("AUTOTEST_FAIL: " + message)


func _check_match() -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	if frames % 30 != 0:
		return
	if not checked.has("map") and match_node.map_data != null:
		checked["map"] = true
		var targets: Array = []
		for o in match_node.map_data.objectives:
			targets.append(o["tile"])
		targets.append_array(match_node.map_data.spawn_cop)
		if match_node.map_data.spawn_crim.is_empty() or match_node.map_data.spawn_cop.is_empty():
			_fail("missing spawn tiles")
		elif not match_node.map_data.all_reachable(match_node.map_data.spawn_crim, targets):
			_fail("map is not fully connected")
	if not checked.has("chars"):
		checked["chars"] = true
		if match_node.characters.is_empty():
			_fail("no characters spawned")
		else:
			var alive_bots := 0
			for c in match_node.characters:
				if c.is_bot and c.alive:
					alive_bots += 1
			if alive_bots == 0:
				_fail("no alive bots")
	if not checked.has("hud"):
		checked["hud"] = true
		if match_node.hud == null:
			_fail("HUD missing")
	if not checked.has("combat"):
		checked["combat"] = true
		var shooter: Character = null
		for c in match_node.characters:
			if c.team == GameTypes.Team.CRIMINALS and c.alive:
				shooter = c
				break
		if shooter == null:
			_fail("no criminal character for combat check")
		else:
			var weapon: Weapon = shooter.get_weapon()
			if weapon == null:
				_fail("no weapon on character")
			elif weapon.ammo_in_mag <= 0:
				_fail("weapon started empty")
			else:
				shooter.want_fire = true


func _finish() -> void:
	if failures.is_empty():
		print("AUTOTEST_OK frames=%d" % frames)
		quit(0)
	else:
		for f in failures:
			printerr("AUTOTEST_FAILURE: " + str(f))
		print("AUTOTEST_FAILED frames=%d failures=%d" % [frames, failures.size()])
		quit(1)
