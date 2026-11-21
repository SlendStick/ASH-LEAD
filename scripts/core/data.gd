class_name Data
extends RefCounted
## Read-only access to JSON data files with caching.

static var _cache: Dictionary = {}


static func _load(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("ASH&LEAD: data file missing: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	_cache[path] = parsed
	return parsed


static func weapons() -> Array:
	var d: Variant = _load("res://data/weapons.json")
	return Array(d.get("weapons", [])) if d is Dictionary else []


static func weapon(id: String) -> Dictionary:
	for w in weapons():
		if String(w.get("id", "")) == id:
			return w
	return {}


static func modes() -> Array:
	var d: Variant = _load("res://data/modes.json")
	return Array(d.get("modes", [])) if d is Dictionary else []


static func mode(id: String) -> Dictionary:
	for m in modes():
		if String(m.get("id", "")) == id:
			return m
	return {}


static func maps() -> Array:
	var d: Variant = _load("res://data/maps.json")
	return Array(d.get("maps", [])) if d is Dictionary else []


static func map(id: String) -> Dictionary:
	for m in maps():
		if String(m.get("id", "")) == id:
			return m
	return {}


static func roles() -> Array:
	var d: Variant = _load("res://data/roles.json")
	return Array(d.get("roles", [])) if d is Dictionary else []


static func role(id: String) -> Dictionary:
	for r in roles():
		if String(r.get("id", "")) == id:
			return r
	return {}


static func civilians() -> Array:
	var d: Variant = _load("res://data/civilians.json")
	return Array(d.get("civilians", [])) if d is Dictionary else []


static func civilian(id: String) -> Dictionary:
	for c in civilians():
		if String(c.get("id", "")) == id:
			return c
	return {}
