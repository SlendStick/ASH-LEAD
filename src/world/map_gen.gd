class_name MapGen
extends RefCounted
## Procedural level generator.
##
## Design goals (Hotline Miami x Counter-Strike x PAYDAY):
##   * claustrophobic rooms connected by short, deadly corridors
##   * at least two loops around the building so nobody is ever fully safe
##   * long sightlines only along a few "shooting lanes", broken by pillars
##   * one main entrance, one service entrance and a roof/fire-escape route
##   * every room has 1-2 doors => predictable angles, unpredictable fights
##
## The generator is fully deterministic from (theme, seed, mode): the host
## generates, sends `to_dict()` and every client rebuilds identical geometry.

## Tile ids mirrored from GeneratedMap. Enum members of a `class_name` are not
## constant expressions in GDScript, so they cannot be used in `const`.
const TK_VOID := 0
const TK_FLOOR := 1
const TK_STREET := 2
const TK_WALL := 3
const TK_WINDOW := 4
const TK_DOOR := 5
const TK_GRATE := 6
const TK_RAIL := 7
const TK_WATER := 8
const TK_CRATE := 9

const ROOM_KINDS := {
	"shop": ["shop", "storage", "security", "shop", "kitchen", "storage"],
	"hospital": ["ward", "ward", "corridor", "storage", "security", "office", "kitchen"],
	"warehouse": ["storage", "storage", "yard", "office", "security", "corridor"],
	"school": ["classroom", "classroom", "corridor", "hall", "office", "storage"],
	"cinema": ["hall", "lobby", "corridor", "storage", "kitchen", "shop"],
	"mall": ["shop", "shop", "lobby", "corridor", "storage", "hall"],
	"bank": ["lobby", "office", "vault", "security", "corridor", "office"],
	"precinct": ["lobby", "office", "cell", "security", "storage", "corridor"],
	"subway": ["hall", "corridor", "shop", "storage", "security", "lobby"],
	"penthouse": ["vip", "office", "hall", "kitchen", "corridor", "storage"],
	"street": ["shop", "storage", "lobby", "security", "yard"],
	"roof": ["roof", "storage", "roof", "security"],
}

const WALL_ROOM_KINDS := ["lobby", "vault", "security", "hostage", "office"]


static func end_of(r: Rect2i) -> Vector2i:
	return r.position + r.size


static func generate(theme_id: String, seed_value: int, mode_id: String) -> GeneratedMap:
	var gm := GeneratedMap.new()
	gm.theme_id = theme_id
	gm.theme = Db.MAPS.get(theme_id, Db.MAPS["asphalt_night"])
	gm.mode_id = mode_id
	gm.seed_value = seed_value
	gm.name = str(gm.theme.get("name", "UNKNOWN"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ttype := str(gm.theme.get("type", "street"))
	if ttype == "street" or ttype == "roof":
		_gen_open(gm, rng)
	else:
		_gen_building(gm, rng)
	_ensure_connectivity(gm, rng)
	_scatter_props(gm, rng)
	_place_lights(gm, rng)
	_place_objectives(gm, rng)
	_build_cover(gm)
	_make_patrols(gm, rng)
	gm.build_caches()
	gm.compute_bounds()
	return gm


# ---------------------------------------------------------------------------
# INTERIOR BUILDINGS (hospital, bank, mall, school, cinema, warehouse, ...)
# ---------------------------------------------------------------------------

static func _gen_building(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	var size: Array = gm.theme.get("size", [5, 4])
	var gw: int = clampi(int(size[0]), 3, 8)
	var gh: int = clampi(int(size[1]), 3, 6)
	var cw := rng.randi_range(2, 3)
	var sm := rng.randi_range(5, 7)  # street ring width

	var rw: Array[int] = []
	var rh: Array[int] = []
	var base_rw := clampi(int(round(66.0 / float(gw))) - cw, 5, 11)
	var base_rh := clampi(int(round(48.0 / float(gh))) - cw, 4, 9)
	for i in range(gw):
		rw.append(clampi(base_rw + rng.randi_range(-1, 1), 4, 12))
	for i in range(gh):
		rh.append(clampi(base_rh + rng.randi_range(-1, 1), 4, 10))

	var bw := cw + gw * cw
	for i in range(gw):
		bw += rw[i]
	var bh := cw + gh * cw
	for i in range(gh):
		bh += rh[i]

	gm.w = sm * 2 + bw
	gm.h = sm * 2 + bh
	gm.tiles.resize(gm.w * gm.h)
	gm.tiles.fill(TK_STREET)
	# boundary void outside the playable asphalt
	for x in range(gm.w):
		gm.set_tile(Vector2i(x, 0), TK_VOID)
		gm.set_tile(Vector2i(x, gm.h - 1), TK_VOID)
	for y in range(gm.h):
		gm.set_tile(Vector2i(0, y), TK_VOID)
		gm.set_tile(Vector2i(gm.w - 1, y), TK_VOID)

	var bx := sm
	var by := sm
	gm.set_tile(Vector2i(bx, by), TK_WALL)
	_fill(gm, Rect2i(bx, by, bw, bh), TK_WALL)

	# room origins
	var room_x: Array[int] = []
	var room_y: Array[int] = []
	var cursor := bx + cw
	for i in range(gw):
		room_x.append(cursor)
		cursor += rw[i] + cw
	cursor = by + cw
	for i in range(gh):
		room_y.append(cursor)
		cursor += rh[i] + cw

	# corridors first (full bands), then rooms on top
	for i in range(gw + 1):
		var cx := bx + i * cw
		for k in range(gw):
			cx += rw[k] if k < i else 0
		_fill(gm, Rect2i(cx, by, cw, bh), TK_FLOOR)
	for j in range(gh + 1):
		var cy := by + j * cw
		for k in range(gh):
			cy += rh[k] if k < j else 0
		_fill(gm, Rect2i(bx, cy, bw, cw), TK_FLOOR)

	# rooms inset by one wall tile
	var kinds: Array[String] = []
	var pool: Array = ROOM_KINDS.get(str(gm.theme.get("type", "shop")), ROOM_KINDS["shop"])
	for j in range(gh):
		for i in range(gw):
			var kind := str(pool[rng.randi_range(0, pool.size() - 1)])
			if j == gh - 1 and i == 0:
				kind = "lobby"
			kinds.append(kind)
	for j in range(gh):
		for i in range(gw):
			var ri := j * gw + i
			var r := Rect2i(room_x[i], room_y[j], rw[i], rh[j])
			_fill(gm, Rect2i(r.position + Vector2i(1, 1), r.size - Vector2i(2, 2)), TK_FLOOR)
			var kind2 := kinds[ri]
			var rname := _room_name(kind2, rng)
			gm.rooms.append({
				"rect": r, "kind": kind2, "name": rname, "floor": rng.randi_range(0, 2),
				"lights_on": rng.randf() > 0.12, "grid": Vector2i(i, j),
				"intel": Db.INTEL_TAGS[rng.randi_range(0, Db.INTEL_TAGS.size() - 1)],
			})
			# doors: every room needs at least one, most get two
			var sides := ["n", "s", "e", "w"]
			_shuffle_arr(sides, rng)
			var door_count := 1 if rng.randf() < 0.25 else 2
			for k in range(door_count):
				var side: String = sides[k]
				var cell := _wall_cell_for_side(r, side, rng)
				if cell != Vector2i(-1, -1):
					_open_door(gm, cell, side, kind2 == "vault" and rng.randf() < 0.7, rng)

	# windows on street-facing walls of edge rooms
	for j in range(gh):
		for i in range(gw):
			var r := Rect2i(room_x[i], room_y[j], rw[i], rh[j])
			if j == 0 and rng.randf() < 0.7:
				_add_window_row(gm, Rect2i(r.position.x + 2, r.position.y, max(1, r.size.x - 4), 1), rng)
			if j == gh - 1 and rng.randf() < 0.7:
				_add_window_row(gm, Rect2i(r.position.x + 2, end_of(r).y - 1, max(1, r.size.x - 4), 1), rng)
			if i == 0 and rng.randf() < 0.6:
				_add_window_row(gm, Rect2i(r.position.x, r.position.y + 2, 1, max(1, r.size.y - 4)), rng)
			if i == gw - 1 and rng.randf() < 0.6:
				_add_window_row(gm, Rect2i(end_of(r).x - 1, r.position.y + 2, 1, max(1, r.size.y - 4)), rng)
			if j == 0 and rng.randf() < 0.35:
				_add_window_row(gm, Rect2i(r.position.x + 2, r.position.y, max(1, r.size.x - 4), 1), rng)

	# entrances: main door from the street into the perimeter corridor
	var entrances: Array[Vector2i] = []
	# main entrance on the bottom edge (street side where criminals arrive)
	var main_x := bx + cw + rw[0] + cw + rng.randi_range(0, max(1, rw[1] - 1))
	var main_y := by + bh - 1
	if gm.tile_at(Vector2i(main_x, main_y)) == TK_WALL:
		gm.set_tile(Vector2i(main_x, main_y), TK_DOOR)
		entrances.append(Vector2i(main_x, main_y))
		gm.doors.append({"cell": Vector2i(main_x, main_y), "side": "s", "open": true, "locked": false, "kind": "main", "hp": 120.0})
	# service entrance on a random edge
	var side_pick := rng.randi_range(0, 3)
	var sx := 0
	var sy := 0
	match side_pick:
		0:
			sx = bx + rng.randi_range(0, bw - 1)
			sy = by
		1:
			sx = bx + rng.randi_range(0, bw - 1)
			sy = by + bh - 1
		2:
			sx = bx
			sy = by + rng.randi_range(0, bh - 1)
		_:
			sx = bx + bw - 1
			sy = by + rng.randi_range(0, bh - 1)
	if gm.tile_at(Vector2i(sx, sy)) == TK_WALL:
		gm.set_tile(Vector2i(sx, sy), TK_DOOR)
		gm.doors.append({"cell": Vector2i(sx, sy), "side": "service", "open": false, "locked": true, "kind": "service", "hp": 100.0})
	# a third doorway for loop flow
	var third_x := bx + rng.randi_range(0, bw - 1)
	var third_y := by
	if gm.tile_at(Vector2i(third_x, third_y)) == TK_WALL:
		gm.set_tile(Vector2i(third_x, third_y), TK_DOOR)
		gm.doors.append({"cell": Vector2i(third_x, third_y), "side": "n", "open": false, "locked": true, "kind": "fire", "hp": 90.0})

	# street puddles, sidewalk edge
	for i in range(rng.randi_range(6, 12)):
		var pc := _random_cell_of(gm, TK_STREET, rng, 1)
		if pc != Vector2i(-1, -1):
			gm.set_tile(pc, TK_WATER)
	# spawns
	gm.spawns_crim = _street_cells(gm, sm, rng, 8, "s")
	gm.spawns_police = _street_cells(gm, sm, rng, 8, "n")
	for j in range(gh):
		for i in range(gw):
			var r2 := Rect2i(room_x[i], room_y[j], rw[i], rh[j])
			if kinds[j * gw + i] == "security" or kinds[j * gw + i] == "lobby":
				gm.spawns_civ.append(_free_cell_in(gm, r2, rng))
	# civilian spawns: 60% in rooms, 40% corridor
	for k in range(10):
		if rng.randf() < 0.65 and gm.rooms.size() > 0:
			var rr: Dictionary = gm.rooms[rng.randi_range(0, gm.rooms.size() - 1)]
			gm.spawns_civ.append(_free_cell_in(gm, rr["rect"], rng))
		else:
			var fc := _random_cell_of(gm, TK_FLOOR, rng, 0)
			if fc != Vector2i(-1, -1):
				gm.spawns_civ.append(fc)


static func _room_name(kind: String, rng: RandomNumberGenerator) -> String:
	var names: Array = GeneratedMap.ROOM_NAMES.get(kind, ["Комната"])
	return str(names[rng.randi_range(0, names.size() - 1)])


static func _wall_cell_for_side(r: Rect2i, side: String, rng: RandomNumberGenerator) -> Vector2i:
	match side:
		"n":
			return Vector2i(r.position.x + rng.randi_range(1, r.size.x - 2), r.position.y)
		"s":
			return Vector2i(r.position.x + rng.randi_range(1, r.size.x - 2), end_of(r).y - 1)
		"w":
			return Vector2i(r.position.x, r.position.y + rng.randi_range(1, r.size.y - 2))
		_:
			return Vector2i(end_of(r).x - 1, r.position.y + rng.randi_range(1, r.size.y - 2))


static func _add_window_row(gm: GeneratedMap, rect: Rect2i, rng: RandomNumberGenerator) -> void:
	var count := 0
	for y in range(rect.position.y, end_of(rect).y):
		for x in range(rect.position.x, end_of(rect).x):
			var c := Vector2i(x, y)
			if gm.tile_at(c) == TK_WALL and rng.randf() < 0.55:
				gm.set_tile(c, TK_WINDOW)
				gm.windows.append(c)
				count += 1
				if count > 4:
					return


static func _open_door(gm: GeneratedMap, cell: Vector2i, side: String, locked: bool, rng: RandomNumberGenerator) -> void:
	if gm.tile_at(cell) != TK_WALL:
		return
	gm.set_tile(cell, TK_DOOR)
	var is_open := rng.randf() < 0.55
	gm.doors.append({
		"cell": cell, "side": side, "open": is_open, "locked": locked,
		"kind": "interior", "hp": 90.0 if not locked else 200.0,
	})


# ---------------------------------------------------------------------------
# OPEN MAPS (street, roof, parking lot)
# ---------------------------------------------------------------------------

static func _gen_open(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	var size: Array = gm.theme.get("size", [6, 4])
	gm.w = clampi(20 + int(size[0]) * 8, 48, 84)
	gm.h = clampi(16 + int(size[1]) * 7, 30, 52)
	gm.tiles.resize(gm.w * gm.h)
	gm.tiles.fill(TK_STREET)
	for x in range(gm.w):
		gm.set_tile(Vector2i(x, 0), TK_VOID)
		gm.set_tile(Vector2i(x, 1), TK_VOID)
		gm.set_tile(Vector2i(x, gm.h - 1), TK_VOID)
		gm.set_tile(Vector2i(x, gm.h - 2), TK_VOID)
	for y in range(gm.h):
		gm.set_tile(Vector2i(0, y), TK_VOID)
		gm.set_tile(Vector2i(1, y), TK_VOID)
		gm.set_tile(Vector2i(gm.w - 1, y), TK_VOID)
		gm.set_tile(Vector2i(gm.w - 2, y), TK_VOID)

	# perimeter buildings / fences
	var block_count := rng.randi_range(3, 6)
	for b in range(block_count):
		var bw := rng.randi_range(6, 12)
		var bh := rng.randi_range(5, 9)
		var bx := rng.randi_range(4, max(5, gm.w - bw - 4))
		var by := rng.randi_range(4, max(5, gm.h - bh - 4))
		# avoid the central lanes
		if abs(bx + bw / 2 - gm.w / 2) < 5 or abs(by + bh / 2 - gm.h / 2) < 5:
			continue
		var r := Rect2i(bx, by, bw, bh)
		_fill(gm, r, TK_WALL)
		_fill(gm, Rect2i(r.position + Vector2i(1, 1), r.size - Vector2i(2, 2)), TK_FLOOR)
		var kind := str(["shop", "storage", "lobby"][rng.randi_range(0, 2)])
		gm.rooms.append({"rect": r, "kind": kind, "name": _room_name(kind, rng), "floor": rng.randi_range(0, 2), "lights_on": true, "grid": Vector2i(b, 0), "intel": "Дверь плохо закрывается. Плохо для нас."})
		var door_cell := Vector2i(bx + rng.randi_range(2, bw - 3), by + bh - 1)
		if gm.tile_at(door_cell) == TK_WALL:
			gm.set_tile(door_cell, TK_DOOR)
			gm.doors.append({"cell": door_cell, "side": "s", "open": true, "locked": false, "kind": "shop", "hp": 80.0})
		if rng.randf() < 0.6:
			_add_window_row(gm, Rect2i(bx + 2, by, max(1, bw - 4), 1), rng)

	# street furniture acting as cover / sightline breakers
	var obstacle_count := int(gm.w * gm.h / 55.0)
	for i in range(obstacle_count):
		var c := _random_cell_of(gm, TK_STREET, rng, 3)
		if c == Vector2i(-1, -1):
			continue
		gm.set_tile(c, TK_GRATE)
		if rng.randf() < 0.5 and gm.tile_at(c + Vector2i(1, 0)) == TK_STREET:
			gm.set_tile(c + Vector2i(1, 0), TK_GRATE)
	# a few parked car blocks (full cover)
	for i in range(rng.randi_range(4, 9)):
		var cc := _random_cell_of(gm, TK_STREET, rng, 4)
		if cc == Vector2i(-1, -1) or abs(cc.x - gm.w / 2) < 4:
			continue
		for k in range(3):
			var p := cc + Vector2i(k, 0)
			if gm.tile_at(p) == TK_STREET:
				gm.set_tile(p, TK_CRATE)
		gm.props.append({"cell": cc, "kind": "car", "rot": 0.0, "scale": 1.0})
	# puddles & neon reflections
	for i in range(rng.randi_range(10, 20)):
		var pc := _random_cell_of(gm, TK_STREET, rng, 2)
		if pc != Vector2i(-1, -1):
			gm.set_tile(pc, TK_WATER)
	# spawns
	gm.spawns_crim = _street_cells(gm, 2, rng, 8, "s")
	gm.spawns_police = _street_cells(gm, 2, rng, 8, "n")
	for k in range(14):
		gm.spawns_civ.append(_random_cell_of(gm, TK_STREET, rng, 2))
	for k in range(4):
		gm.spawns_civ.append(_random_cell_of(gm, TK_FLOOR, rng, 1))


# ---------------------------------------------------------------------------
# PROPS / LIGHTS / OBJECTIVES / COVER / PATROLS
# ---------------------------------------------------------------------------

static func _scatter_props(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	var pool: Array = gm.theme.get("props", ["crate"])
	for i in range(gm.rooms.size()):
		var r: Dictionary = gm.rooms[i]
		var rect: Rect2i = r["rect"]
		var kind := str(r["kind"])
		var count := rng.randi_range(3, 7)
		for k in range(count):
			var c := _free_cell_in(gm, rect, rng)
			if c == Vector2i(-1, -1):
				continue
			var prop_kind := _prop_for_room(kind, pool, rng)
			gm.props.append({"cell": c, "kind": prop_kind, "rot": [0.0, PI * 0.5, PI, PI * 1.5][rng.randi_range(0, 3)], "scale": rng.randf_range(0.85, 1.15)})
			if _prop_is_solid(prop_kind) and rng.randf() < 0.6:
				gm.set_tile(c, TK_CRATE)
			elif prop_kind == "puddle" or prop_kind == "blood_pool":
				gm.set_tile(c, TK_WATER)
	# corridor clutter
	for i in range(int(gm.w * gm.h / 90.0)):
		var c2 := _random_cell_of(gm, TK_FLOOR, rng, 1)
		if c2 == Vector2i(-1, -1):
			continue
		var k2 := str(["chair", "trash", "cone", "crate", "blood_pool", "shells"][rng.randi_range(0, 5)])
		gm.props.append({"cell": c2, "kind": k2, "rot": rng.randf_range(0.0, TAU), "scale": rng.randf_range(0.8, 1.2)})
		if k2 == "crate" and rng.randf() < 0.5:
			gm.set_tile(c2, TK_CRATE)
		elif k2 == "blood_pool":
			gm.set_tile(c2, TK_WATER)
	# street / exterior neon signage + streetlights props
	if gm.theme.get("type", "") == "street":
		for i in range(rng.randi_range(6, 10)):
			var sc := _random_cell_of(gm, TK_STREET, rng, 3)
			if sc != Vector2i(-1, -1):
				gm.props.append({"cell": sc, "kind": "neon_sign", "rot": 0.0, "scale": rng.randf_range(0.8, 1.3), "color": gm.theme.get("accent", "#ff2b62")})


static func _prop_for_room(kind: String, pool: Array, rng: RandomNumberGenerator) -> String:
	var by_kind := {
		"ward": ["gurney", "iv_stand", "chair", "monitor"],
		"office": ["desk", "chair", "cabinet", "printer"],
		"vault": ["cash_rack", "safe", "pallet"],
		"security": ["desk", "monitor", "chair", "camera_rig"],
		"shop": ["shelf", "fridge", "counter", "register"],
		"storage": ["crate", "pallet", "barrel", "shelf"],
		"kitchen": ["counter", "fridge", "table", "knife_block"],
		"classroom": ["desk", "chalkboard", "cabinet"],
		"hall": ["chair", "speaker", "trash"],
		"cell": ["bench", "bars", "toilet"],
		"lobby": ["chair", "plant", "counter", "ashtray"],
		"vip": ["couch", "bar", "safe", "piano"],
		"yard": ["pallet", "forklift", "barrel"],
		"roof": ["ac_unit", "vent", "dish", "water_tank"],
		"hostage": ["chair", "couch", "table"],
		"corridor": ["chair", "trash", "plant"],
	}
	var list: Array = by_kind.get(kind, [])
	if list.is_empty():
		list = ["chair", "trash"] if pool.is_empty() else pool
	return str(list[rng.randi_range(0, list.size() - 1)])


static func _prop_is_solid(kind: String) -> bool:
	return kind in ["shelf", "fridge", "counter", "desk", "cabinet", "crate", "pallet", "barrel",
		"gurney", "vault_door", "safe", "cash_rack", "forklift", "piano", "couch", "ac_unit",
		"water_tank", "machine", "container", "car", "dumpster", "bars"]


static func _place_lights(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	var accent := str(gm.theme.get("accent", "#ff2b62"))
	var accent2 := str(gm.theme.get("accent2", "#35c9ff"))
	var interior := gm.is_interior()
	for i in range(gm.rooms.size()):
		var r: Dictionary = gm.rooms[i]
		var rect: Rect2i = r["rect"]
		if not bool(r.get("lights_on", true)):
			continue
		var cols := [accent, accent2, "#ffb02b", "#bfefff"]
		var count := int(rect.size.x / 4)
		for k in range(max(1, count)):
			var c := Vector2i(rect.position.x + 2 + k * 4, rect.position.y + rect.size.y / 2)
			gm.lights.append({
				"cell": c, "color": str(cols[rng.randi_range(0, cols.size() - 1)]),
				"radius": rng.randf_range(150.0, 260.0), "kind": "room",
				"flicker": rng.randf() < 0.25, "power": rng.randf_range(0.7, 1.3),
			})
	if interior:
		for i in range(rng.randi_range(6, 12)):
			var c2 := _random_cell_of(gm, TK_FLOOR, rng, 1)
			if c2 != Vector2i(-1, -1):
				gm.lights.append({"cell": c2, "color": "#35c9ff", "radius": 120.0, "kind": "emergency", "flicker": true, "power": 0.6})
	for i in range(rng.randi_range(8, 16)):
		var c3 := _random_cell_of(gm, TK_STREET, rng, 2)
		if c3 != Vector2i(-1, -1):
			gm.lights.append({"cell": c3, "color": "#ffb02b" if rng.randf() < 0.5 else "#35c9ff", "radius": 230.0, "kind": "street", "flicker": rng.randf() < 0.15, "power": 1.0})


static func _place_objectives(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	var mode := gm.mode_id
	var centers: Array[Vector2i] = []
	for r in gm.rooms:
		var rect: Rect2i = r["rect"]
		centers.append(Vector2i(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2))
	# interior points by mode
	var hostage_room := -1
	var vault_rooms: Array[int] = []
	for i in range(gm.rooms.size()):
		var kind := str(gm.rooms[i]["kind"])
		if kind == "hostage" or (kind == "lobby" and hostage_room < 0):
			hostage_room = i
		if kind == "vault":
			vault_rooms.append(i)
	if hostage_room < 0 and gm.rooms.size() > 0:
		hostage_room = rng.randi_range(0, gm.rooms.size() - 1)
	if vault_rooms.is_empty() and gm.rooms.size() > 2:
		vault_rooms.append(rng.randi_range(1, gm.rooms.size() - 1))
	if gm.rooms.size() > 0:
		gm.points["hostage_room"] = gm.rooms[hostage_room]["rect"].position + gm.rooms[hostage_room]["rect"].size / 2
	var vaults: Array = []
	for i in vault_rooms:
		var rr: Rect2i = gm.rooms[i]["rect"]
		vaults.append(gm.cell_to_world(rr.position + rr.size / 2))
	gm.points["vaults"] = vaults
	# bomb sites: 3 spread-out room centers
	var sites: Array = []
	var picks := [0, int(gm.rooms.size() / 2), max(0, gm.rooms.size() - 1)]
	if gm.rooms.size() > 4:
		picks = [rng.randi_range(0, gm.rooms.size() / 3), rng.randi_range(gm.rooms.size() / 3, 2 * gm.rooms.size() / 3), rng.randi_range(2 * gm.rooms.size() / 3, gm.rooms.size() - 1)]
	for p in picks:
		var rr2: Rect2i = gm.rooms[p]["rect"]
		sites.append(gm.cell_to_world(rr2.position + rr2.size / 2))
	gm.points["bomb_sites"] = sites
	# domination points: 3 far-apart locations
	var caps: Array = []
	var candidates: Array = centers.duplicate()
	_shuffle_arr(candidates, rng)
	for c in candidates:
		if caps.size() >= 3:
			continue
		var ok := true
		for existing in caps:
			if (existing as Vector2i).distance_to(c) < 12:
				ok = false
		if ok:
			caps.append(c)
	if caps.size() < 3:
		caps = centers.slice(0, 3)
	var cap_world: Array = []
	for c in caps:
		cap_world.append(gm.cell_to_world(c))
	gm.points["capture"] = cap_world
	# extraction / getaway van in the street
	var street := _random_cell_of(gm, TK_STREET, rng, 3)
	if street == Vector2i(-1, -1):
		street = Vector2i(3, gm.h - 4)
	gm.points["extract"] = gm.cell_to_world(street)
	# security room / camera hub
	for i in range(gm.rooms.size()):
		if str(gm.rooms[i]["kind"]) == "security":
			var rr3: Rect2i = gm.rooms[i]["rect"]
			gm.points["security_room"] = gm.cell_to_world(rr3.position + rr3.size / 2)
			break
	# spawn safety: criminals near the south street, police north, unless the mode
	# starts the police inside (bomb_defuse / precinct).
	if mode == "bomb_defuse" and gm.spawns_police.is_empty():
		gm.spawns_police = _street_cells(gm, 4, rng, 8, "s")


static func _build_cover(gm: GeneratedMap) -> void:
	for y in range(1, gm.h - 1):
		for x in range(1, gm.w - 1):
			var c := Vector2i(x, y)
			if not gm.walkable(c):
				continue
			var near_wall := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var t := gm.tile_at(c + d)
				if t == TK_WALL or t == TK_CRATE or t == TK_GRATE or t == TK_WINDOW:
					near_wall = true
			if near_wall:
				gm.cover.append(c)


static func _make_patrols(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	var corridor: Array[Vector2i] = []
	for y in range(1, gm.h - 1):
		for x in range(1, gm.w - 1):
			var c := Vector2i(x, y)
			if gm.tile_at(c) == TK_FLOOR and gm.room_at_cell(c) < 0:
				corridor.append(c)
	var count := clampi(gm.rooms.size() / 2, 1, 4)
	for p in range(count):
		var loop: Array = []
		var points_n := rng.randi_range(3, 5)
		for k in range(points_n):
			var pick: Vector2i
			if corridor.size() > 10 and rng.randf() < 0.6:
				pick = corridor[rng.randi_range(0, corridor.size() - 1)]
			elif gm.rooms.size() > 0:
				var rr: Rect2i = gm.rooms[rng.randi_range(0, gm.rooms.size() - 1)]["rect"]
				pick = _free_cell_in(gm, rr, rng)
			else:
				pick = _random_cell_of(gm, TK_STREET, rng, 2)
			if pick == Vector2i(-1, -1):
				continue
			var occupied := false
			for existing in loop:
				if (existing as Vector2i).distance_to(pick) < 6:
					occupied = true
			if not occupied:
				loop.append(pick)
		if loop.size() >= 2:
			gm.patrols.append(loop)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

static func _shuffle_arr(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _ensure_connectivity(gm: GeneratedMap, rng: RandomNumberGenerator) -> void:
	## Flood-fill the interior floor from the main entrance; any room that cannot
	## be reached gets a corridor punched to the nearest reachable floor tile.
	var start := Vector2i(-1, -1)
	for i in range(gm.doors.size()):
		var d: Dictionary = gm.doors[i]
		if str(d.get("kind", "")) == "main":
			start = d["cell"]
			break
	if start == Vector2i(-1, -1):
		start = _random_cell_of(gm, TK_FLOOR, rng, 4)
	if start == Vector2i(-1, -1):
		return
	var seen := {}
	var queue: Array[Vector2i] = []
	# flood from the street tile just outside the main door, through floor
	var seeds: Array[Vector2i] = [start]
	for i in range(gm.doors.size()):
		var dd: Dictionary = gm.doors[i]
		seeds.append(dd["cell"])
	for s in seeds:
		if gm.walkable(s) or gm.tile_at(s) == TK_DOOR:
			queue.append(s)
			seen[s] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d2
			if seen.has(n) or not gm.in_bounds(n):
				continue
			var t := gm.tile_at(n)
			if t == TK_FLOOR or t == TK_DOOR or t == TK_STREET:
				seen[n] = true
				queue.append(n)
	for i in range(gm.rooms.size()):
		var rect: Rect2i = gm.rooms[i]["rect"]
		var center := rect.position + rect.size / 2
		if seen.has(center) or rooms_connected(gm, rect, seen):
			continue
		# punch towards the closest reachable tile
		var target := Vector2i(-1, -1)
		var best := 1e9
		for y in range(max(1, rect.position.y - 18), min(gm.h - 1, end_of(rect).y + 18)):
			for x in range(max(1, rect.position.x - 18), min(gm.w - 1, end_of(rect).x + 18)):
				var c3 := Vector2i(x, y)
				if seen.has(c3):
					var dd3 := Vector2(c3).distance_squared_to(Vector2(center))
					if dd3 < best:
						best = dd3
						target = c3
		if target == Vector2i(-1, -1):
			continue
		var axis := "h" if abs(target.x - center.x) > abs(target.y - center.y) else "v"
		var cur := center
		var guard := 0
		while cur != target and guard < 200:
			guard += 1
			if axis == "h":
				cur.x += signi(target.x - cur.x)
			else:
				cur.y += signi(target.y - cur.y)
			if gm.in_bounds(cur):
				var tt := gm.tile_at(cur)
				if tt == TK_WALL or tt == TK_WINDOW:
					gm.set_tile(cur, TK_DOOR)
					gm.doors.append({"cell": cur, "side": "cut", "open": true, "locked": false, "kind": "cut", "hp": 70.0})
				elif tt == TK_VOID:
					gm.set_tile(cur, TK_FLOOR)


static func rooms_connected(gm: GeneratedMap, rect: Rect2i, seen: Dictionary) -> bool:
	for y in range(rect.position.y + 1, end_of(rect).y - 1):
		for x in range(rect.position.x + 1, end_of(rect).x - 1):
			if seen.has(Vector2i(x, y)):
				return true
	return false


static func _fill(gm: GeneratedMap, rect: Rect2i, t: int) -> void:
	for y in range(rect.position.y, end_of(rect).y):
		for x in range(rect.position.x, end_of(rect).x):
			gm.set_tile(Vector2i(x, y), t)


static func _free_cell_in(gm: GeneratedMap, rect: Rect2i, rng: RandomNumberGenerator) -> Vector2i:
	for attempt in range(40):
		var c := Vector2i(rng.randi_range(rect.position.x + 1, end_of(rect).x - 2), rng.randi_range(rect.position.y + 1, end_of(rect).y - 2))
		if gm.walkable(c):
			return c
	return Vector2i(-1, -1)


static func _random_cell_of(gm: GeneratedMap, t: int, rng: RandomNumberGenerator, attempts: int) -> Vector2i:
	for a in range(max(1, attempts * 60)):
		var c := Vector2i(rng.randi_range(2, gm.w - 3), rng.randi_range(2, gm.h - 3))
		if gm.tile_at(c) == t:
			return c
	return Vector2i(-1, -1)


static func _street_cells(gm: GeneratedMap, margin: int, rng: RandomNumberGenerator, count: int, side: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tries := 0
	while out.size() < count and tries < 4000:
		tries += 1
		var c: Vector2i
		match side:
			"s":
				c = Vector2i(rng.randi_range(2, gm.w - 3), rng.randi_range(gm.h - margin, gm.h - 3))
			"n":
				c = Vector2i(rng.randi_range(2, gm.w - 3), rng.randi_range(2, margin + 1))
			"e":
				c = Vector2i(rng.randi_range(gm.w - margin, gm.w - 3), rng.randi_range(2, gm.h - 3))
			_:
				c = Vector2i(rng.randi_range(2, margin + 1), rng.randi_range(2, gm.h - 3))
		if gm.tile_at(c) == TK_STREET:
			var dup := false
			for o in out:
				if o.distance_to(c) < 2:
					dup = true
			if not dup:
				out.append(c)
	return out
