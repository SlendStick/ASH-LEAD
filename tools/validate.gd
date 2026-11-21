extends SceneTree
## Static validation of the ASH&LEAD project.
## Loads every script, scene and data file, checks that resources resolve,
## and prints VALIDATE_OK on success. Exits with code 1 on any failure.

var failures: Array = []
var checks: int = 0


func _initialize() -> void:
	TestEnv.ensure_autoloads(root)
	_check_scripts()
	_check_scenes()
	_check_data()
	_check_textures()
	_check_sounds()
	_check_locale()
	_report()


func _report() -> void:
	if failures.is_empty():
		print("VALIDATE_OK checks=%d" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("VALIDATION_FAIL: " + str(f))
		print("VALIDATE_FAILED checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _fail(msg: String) -> void:
	failures.append(msg)


func _list_files(path: String, ext: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				out.append_array(_list_files(path.path_join(name), ext))
		elif name.ends_with(ext):
			out.append(path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _check_scripts() -> void:
	for p in _list_files("res://scripts", ".gd"):
		checks += 1
		var s: Variant = load(p)
		if s == null:
			_fail("script load failed: " + p)
	for p in _list_files("res://autoload", ".gd"):
		checks += 1
		var s: Variant = load(p)
		if s == null:
			_fail("autoload load failed: " + p)


func _check_scenes() -> void:
	for p in _list_files("res://scenes", ".tscn"):
		checks += 1
		var ps: Variant = load(p)
		if ps == null:
			_fail("scene load failed: " + p)
			continue
		var inst: Node = null
		var err := ps.can_instantiate() if ps is PackedScene else false
		if ps is PackedScene and err:
			inst = ps.instantiate()
			if inst == null:
				_fail("scene instantiate failed: " + p)
			else:
				inst.free()


func _check_data() -> void:
	for p in _list_files("res://data", ".json"):
		checks += 1
		if not FileAccess.file_exists(p):
			_fail("missing data file: " + p)
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		var txt := f.get_as_text()
		f.close()
		var j := JSON.new()
		var err := j.parse(txt)
		if err != OK:
			_fail("json parse failed: " + p + " : " + j.get_error_message())


func _check_textures() -> void:
	for p in _list_files("res://assets/textures", ".png"):
		checks += 1
		var t: Variant = load(p)
		if t == null:
			_fail("texture load failed: " + p)
	for p in _list_files("res://assets/textures", ".svg"):
		checks += 1
		var t: Variant = load(p)
		if t == null:
			_fail("texture load failed: " + p)


func _check_sounds() -> void:
	for folder in ["res://assets/sounds", "res://assets/music"]:
		for p in _list_files(folder, ".wav"):
			checks += 1
			var s: Variant = load(p)
			if s == null:
				_fail("audio load failed: " + p)


func _check_locale() -> void:
	var path := "res://locale/translations.json"
	checks += 1
	if not FileAccess.file_exists(path):
		_fail("missing locale file: " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var j := JSON.new()
	var err := j.parse(f.get_as_text())
	f.close()
	if err != OK:
		_fail("locale json parse failed: " + j.get_error_message())
		return
	var table: Dictionary = j.get_data()
	var used := _collect_locale_keys()
	for key in used:
		checks += 1
		if key.ends_with("_"):
			# Dynamic prefix key, e.g. Localization.t("mode_" + id).
			continue
		if not table.has(key):
			_fail("missing locale key: " + key)
			continue
		var entry: Variant = table[key]
		if entry is Dictionary and not (entry.has("ru") and entry.has("en")):
			_fail("locale key without ru/en: " + key)
	var loc := load("res://autoload/localization.gd")
	checks += 1
	if loc == null:
		_fail("localization autoload failed to load")


func _collect_locale_keys() -> Array:
	var keys := {}
	var files := _list_files("res://scripts", ".gd") + _list_files("res://autoload", ".gd")
	for p in files:
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		var pos := 0
		while true:
			var found := text.find("Localization.t(", pos)
			if found < 0:
				break
			var start := found + "Localization.t(".length()
			while start < text.length() and text[start] in [" ", "\t"]:
				start += 1
			if start < text.length() and text[start] == '"':
				var end := text.find('"', start + 1)
				if end > start:
					keys[text.substr(start + 1, end - start - 1)] = true
			pos = start
	return keys.keys()
