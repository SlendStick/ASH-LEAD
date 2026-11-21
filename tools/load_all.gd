extends SceneTree
## Loads every GDScript in the project and reports failures with the engine's
## own diagnostics. Used by CI to surface parse errors that static parsers
## (gdtoolkit) do not catch.

var _failures := 0


func _initialize() -> void:
	print("LOAD_ALL_BEGIN")
	var files: Array = []
	_collect("res://autoload", files)
	_collect("res://scripts", files)
	_collect("res://tools", files)
	files.sort()
	# Load the core classes first: their own diagnostics are otherwise masked
	# by "Could not parse global class ..." errors in dependent scripts.
	var core_first: Array = [
		"res://scripts/core/types.gd",
		"res://scripts/core/utils.gd",
		"res://scripts/core/data.gd",
		"res://scripts/core/weapon.gd",
		"res://scripts/core/character.gd",
		"res://scripts/core/interactable.gd",
		"res://scripts/map/map_data.gd",
		"res://scripts/map/props.gd",
		"res://scripts/map/door.gd",
		"res://scripts/map/map_view.gd",
		"res://scripts/map/map_generator.gd",
		"res://scripts/match/match.gd",
		"res://scripts/match/replay_recorder.gd",
		"res://scripts/modes/game_mode.gd",
	]
	var ordered: Array = []
	for path in core_first:
		if files.has(path):
			ordered.append(path)
	for path in files:
		if not ordered.has(path):
			ordered.append(path)
	files = ordered
	for path in files:
		print("### LOADING ", path)
		var script: GDScript = load(path)
		if script == null:
			print("LOAD_FAIL ", path)
			_failures += 1
			continue
		if script.can_instantiate():
			print("LOAD_OK ", path)
		else:
			print("LOAD_NOINSTANCE ", path)
			_failures += 1
	print("LOAD_ALL_END files=", files.size(), " failures=", _failures)
	quit(_failures)


func _collect(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path + "/" + name
		if d.current_is_dir():
			if name != "." and name != "..":
				_collect(full, out)
		elif name.ends_with(".gd"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
