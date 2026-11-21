class_name MapGenerator
extends RefCounted
## Procedural map generator: original room modules connected by corridors,
## validated for connectivity, spawn safety and objective reachability.

const ROOM_SETS := {
	"clinic": [["lobby", 9, 12, 7, 9], ["reception", 6, 8, 5, 7], ["ward", 5, 7, 5, 7],
		["office", 4, 6, 4, 6], ["storage", 4, 5, 4, 5], ["server", 3, 4, 3, 4], ["canteen", 6, 8, 5, 7]],
	"warehouse": [["dock", 10, 13, 8, 10], ["storage", 7, 10, 6, 8], ["office", 5, 7, 4, 6],
		["locker", 4, 5, 4, 5], ["packing", 6, 8, 5, 7], ["yard", 9, 12, 7, 9]],
	"college": [["hall", 9, 12, 7, 9], ["class", 6, 8, 5, 7], ["library", 7, 9, 6, 8],
		["gym", 9, 11, 7, 9], ["canteen", 6, 8, 5, 7], ["lab", 5, 6, 4, 5], ["office", 4, 6, 4, 6]],
	"cinema": [["foyer", 10, 13, 7, 9], ["hall", 9, 11, 8, 10], ["hall", 9, 11, 8, 10],
		["hall", 8, 10, 7, 9], ["snack", 6, 8, 5, 7], ["staff", 5, 6, 4, 5], ["corridor", 8, 10, 3, 4]],
	"mall": [["atrium", 11, 14, 8, 10], ["shop", 6, 8, 5, 7], ["shop", 6, 8, 5, 7],
		["shop", 6, 8, 5, 7], ["food", 7, 9, 6, 8], ["storage", 5, 7, 4, 6], ["parking", 10, 13, 7, 9]],
	"archive": [["lobby", 9, 12, 7, 9], ["office", 5, 7, 4, 6], ["archive", 7, 10, 6, 8],
		["archive", 7, 10, 6, 8], ["meeting", 7, 9, 6, 8], ["server", 4, 5, 4, 5], ["storage", 4, 6, 4, 6]],
}


static func generate(map_id: String, seed_value: int) -> MapData:
	var cfg: Dictionary = Data.map(map_id)
	if cfg.is_empty():
		cfg = Data.map("clinic")
	var size: Array = cfg.get("size", [64, 48])
	var w := int(size[0])
	var h := int(size[1])
	for attempt in 24:
		var rng := RandomNumberGenerator.new()
		rng.seed = (seed_value * 131 + attempt * 104729 + 17) & 0x7FFFFFFF
		var md: MapData = _build(cfg, w, h, rng, seed_value)
		if md != null:
			return md
	return _fallback(cfg, w, h, seed_value)


# ----------------------------------------------------------------------------

static func _build(cfg: Dictionary, w: int, h: int, rng: RandomNumberGenerator, seed_value: int) -> MapData:
	var md := MapData.new(w, h)
	md.theme = String(cfg.get("theme", "clinic"))
	md.seed_value = seed_value
	md.map_name = String(cfg.get("name", "map"))
	md.desc = String(cfg.get("description", ""))
	md.floor_texture = String(cfg.get("floor", "floor_concrete"))
	md.wall_texture = String(cfg.get("wall", "wall"))
	md.ambient = float(cfg.get("ambient", 0.3))
	var lc: Array = cfg.get("light_color", [0.7, 0.85, 0.8])
	md.light_color = Color(float(lc[0]), float(lc[1]), float(lc[2]), 1.0)
	var rooms := _place_rooms(md, rng, int(cfg.get("rooms", 9)))
	if rooms.size() < 4:
		return null
	for r in rooms:
		_carve_room(md, r, rng)
	var corridors := _connect_rooms(md, rng, rooms)
	_place_doors(md, rng, corridors, rooms)
	_walls_around(md)
	if bool(cfg.get("outside", false)):
		_make_outside(md, rng)
	_choose_spawns(md, rng, rooms)
	if md.spawn_crim.is_empty() or md.spawn_cop.is_empty():
		return null
	_place_objectives(md, rng, rooms, cfg)
	_place_evac(md, rng, rooms, cfg)
	_place_lights(md, rng, cfg, rooms)
	_place_props(md, rng, cfg, rooms)
	if not _validate(md):
		return null
	return md


static func _place_rooms(md: MapData, rng: RandomNumberGenerator, target: int) -> Array:
	var theme: String = md.theme
	var set_list: Array = ROOM_SETS.get(theme, ROOM_SETS["clinic"])
	var rooms: Array = []
	var tries := 0
	while rooms.size() < target and tries < 500:
		tries += 1
		var tpl: Array = set_list[rng.randi() % set_list.size()]
		var rw := rng.randi_range(int(tpl[1]), int(tpl[2]))
		var rh := rng.randi_range(int(tpl[3]), int(tpl[4]))
		var margin := 2
		if rw + margin * 2 > md.width or rh + margin * 2 > md.height:
			continue
		var rect := Rect2i(rng.randi_range(margin, md.width - rw - margin),
			rng.randi_range(margin, md.height - rh - margin), rw, rh)
		var ok := true
		for other in rooms:
			var r: Rect2i = other["rect"]
			var padded := Rect2i(r.position - Vector2i(3, 3), r.size + Vector2i(6, 6))
			if padded.intersects(rect):
				ok = false
				break
		if not ok:
			continue
		var tiles: Array = []
		rooms.append({
			"rect": rect,
			"tag": String(tpl[0]),
			"center": Vector2i(rect.position.x + rw / 2, rect.position.y + rh / 2),
			"floor_tiles": tiles,
		})
	return rooms


static func _carve_room(md: MapData, room: Dictionary, rng: RandomNumberGenerator) -> void:
	var rect: Rect2i = room["rect"]
	var tiles: Array = []
	var variant := rng.randi_range(0, 3)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if not md.in_bounds(x, y):
				continue
			md.set_tile(x, y, MapData.Tile.FLOOR, variant)
			tiles.append(Vector2i(x, y))
	room["floor_tiles"] = tiles


static func _connect_rooms(md: MapData, rng: RandomNumberGenerator, rooms: Array) -> Array:
	var corridors: Array = []
	# Prim spanning tree over room centres.
	var connected: Array = [0]
	var remaining: Array = []
	for i in range(1, rooms.size()):
		remaining.append(i)
	while not remaining.is_empty():
		var best_from := -1
		var best_to := -1
		var best_dist := 1 << 30
		for a in connected:
			for b in remaining:
				var d: int = rooms[a]["center"].distance_squared_to(rooms[b]["center"])
				if d < best_dist:
					best_dist = d
					best_from = a
					best_to = b
		corridors.append(_carve_corridor(md, rng, rooms[best_from]["center"], rooms[best_to]["center"]))
		connected.append(best_to)
		remaining.erase(best_to)
	# Extra loops for alternate routes.
	for i in rooms.size():
		if rng.randf() < 0.45:
			var j := rng.randi() % rooms.size()
			if j != i:
				corridors.append(_carve_corridor(md, rng, rooms[i]["center"], rooms[j]["center"]))
	return corridors


static func _carve_corridor(md: MapData, rng: RandomNumberGenerator, a: Vector2i, b: Vector2i) -> Array:
	var path: Array = []
	var cur := a
	if rng.randf() < 0.5:
		_carve_h(md, cur.y, cur.x, b.x, path)
		_carve_v(md, b.x, cur.y, b.y, path)
	else:
		_carve_v(md, cur.x, cur.y, b.y, path)
		_carve_h(md, b.y, cur.x, b.x, path)
	return path


static func _carve_h(md: MapData, y: int, x_from: int, x_to: int, path: Array) -> void:
	var step := 1 if x_to >= x_from else -1
	var x := x_from
	while true:
		_carve_wide(md, x, y, true, path)
		if x == x_to:
			break
		x += step


static func _carve_v(md: MapData, x: int, y_from: int, y_to: int, path: Array) -> void:
	var step := 1 if y_to >= y_from else -1
	var y := y_from
	while true:
		_carve_wide(md, x, y, false, path)
		if y == y_to:
			break
		y += step


static func _carve_wide(md: MapData, x: int, y: int, horizontal: bool, path: Array) -> void:
	for offset in 2:
		var tx := x + (offset if not horizontal else 0)
		var ty := y + (offset if horizontal else 0)
		if tx < 1 or ty < 1 or tx >= md.width - 1 or ty >= md.height - 1:
			continue
		if md.tile_at(tx, ty) == MapData.Tile.VOID:
			md.set_tile(tx, ty, MapData.Tile.FLOOR, 0)
		if not path.has(Vector2i(tx, ty)):
			path.append(Vector2i(tx, ty))


static func _place_doors(md: MapData, rng: RandomNumberGenerator, corridors: Array, rooms: Array) -> void:
	var candidates: Array = []
	for path in corridors:
		for tile in path:
			if _inside_any_room(tile, rooms):
				continue
			var near_room := false
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _inside_any_room(tile + dir, rooms):
					near_room = true
					break
			if near_room:
				candidates.append(tile)
	# Keep at most two doors per room to avoid door spam.
	var per_room := {}
	var chosen: Array = []
	for tile in candidates:
		var room := _nearest_room(tile, rooms)
		var key: String = str(room["rect"])
		var count: int = per_room.get(key, 0)
		if count >= 2:
			continue
		if md.tile_at(tile.x, tile.y) != MapData.Tile.FLOOR:
			continue
		md.set_tile(tile.x, tile.y, MapData.Tile.DOOR, 0)
		var door := {"pos": tile, "open": false, "locked": false, "angle": 0}
		md.doors.append(door)
		md.door_map[tile] = door
		per_room[key] = count + 1
		chosen.append(tile)
	# Entrance doors near the map edge (when no outside area).
	var has_outside := false
	for y in range(md.height):
		for x in range(md.width):
			if md.tile_at(x, y) == MapData.Tile.ROAD:
				has_outside = true
				break
		if has_outside:
			break


static func _inside_any_room(tile: Vector2i, rooms: Array) -> bool:
	for r in rooms:
		if (r["rect"] as Rect2i).has_point(tile):
			return true
	return false


static func _nearest_room(tile: Vector2i, rooms: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1 << 30
	for r in rooms:
		var d: int = (r["center"] as Vector2i).distance_squared_to(tile)
		if d < best_d:
			best_d = d
			best = r
	return best


static func _walls_around(md: MapData) -> void:
	for y in md.height:
		for x in md.width:
			if md.tile_at(x, y) != MapData.Tile.VOID:
				continue
			if x == 0 or y == 0 or x == md.width - 1 or y == md.height - 1:
				md.set_tile(x, y, MapData.Tile.WALL, 0)
				continue
			var near_floor := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if md.tile_at(x + dx, y + dy) != MapData.Tile.VOID:
						near_floor = true
						break
				if near_floor:
					break
			if near_floor:
				md.set_tile(x, y, MapData.Tile.WALL, 0)


static func _make_outside(md: MapData, rng: RandomNumberGenerator) -> void:
	# Building bounding box from carved tiles.
	var min_x := md.width
	var min_y := md.height
	var max_x := 0
	var max_y := 0
	for y in md.height:
		for x in md.width:
			var t := md.tile_at(x, y)
			if t != MapData.Tile.VOID and t != MapData.Tile.WALL:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	# Everything outside the building becomes road/pavement.
	for y in md.height:
		for x in md.width:
			var t := md.tile_at(x, y)
			if t == MapData.Tile.VOID:
				var outside_building := x < min_x or x > max_x or y < min_y or y > max_y
				if outside_building and x > 0 and y > 0 and x < md.width - 1 and y < md.height - 1:
					md.set_tile(x, y, MapData.Tile.ROAD if rng.randf() < 0.7 else MapData.Tile.OUTSIDE, rng.randi_range(0, 1))
	# Entrances: wall tiles touching both road and floor become doors.
	var entrances := 0
	for y in range(1, md.height - 1):
		for x in range(1, md.width - 1):
			if md.tile_at(x, y) != MapData.Tile.WALL:
				continue
			var road := false
			var floor := false
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var t := md.tile_at(x + dir.x, y + dir.y)
				if t == MapData.Tile.ROAD or t == MapData.Tile.OUTSIDE:
					road = true
				elif t == MapData.Tile.FLOOR:
					floor = true
			if road and floor and rng.randf() < 0.5:
				md.set_tile(x, y, MapData.Tile.DOOR, 0)
				md.doors.append({"pos": Vector2i(x, y), "open": false, "locked": false, "angle": 0})
				md.door_map[Vector2i(x, y)] = md.doors[md.doors.size() - 1]
				entrances += 1
	if entrances == 0:
		# Guarantee at least one entrance.
		for y in range(1, md.height - 1):
			for x in range(1, md.width - 1):
				if md.tile_at(x, y) == MapData.Tile.WALL:
					var road := false
					var floor := false
					for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var t := md.tile_at(x + dir.x, y + dir.y)
						if t == MapData.Tile.ROAD or t == MapData.Tile.OUTSIDE:
							road = true
						elif t == MapData.Tile.FLOOR:
							floor = true
					if road and floor:
						md.set_tile(x, y, MapData.Tile.DOOR, 0)
						md.doors.append({"pos": Vector2i(x, y), "open": false, "locked": false, "angle": 0})
						md.door_map[Vector2i(x, y)] = md.doors[md.doors.size() - 1]
						return


static func _choose_spawns(md: MapData, rng: RandomNumberGenerator, rooms: Array) -> void:
	var best_a := 0
	var best_b := 1
	var best_d := -1
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var d: int = rooms[i]["center"].distance_squared_to(rooms[j]["center"])
			if d > best_d:
				best_d = d
				best_a = i
				best_b = j
	var diagonal := Vector2(md.width, md.height).length()
	if Vector2(rooms[best_a]["center"]).distance_to(Vector2(rooms[best_b]["center"])) < diagonal * 0.3:
		return
	md.spawn_crim = _free_tiles_in_room(md, rooms[best_a], 10)
	md.spawn_cop = _free_tiles_in_room(md, rooms[best_b], 10)


static func _free_tiles_in_room(md: MapData, room: Dictionary, count: int) -> Array:
	var tiles: Array = room["floor_tiles"]
	var out: Array = []
	for t in tiles:
		if md.is_walkable(t.x, t.y):
			out.append(t)
		if out.size() >= count:
			break
	return out


static func _place_objectives(md: MapData, rng: RandomNumberGenerator, rooms: Array, cfg: Dictionary) -> void:
	var spawn_rooms: Array = []
	for r in rooms:
		for t in md.spawn_crim + md.spawn_cop:
			if (r["rect"] as Rect2i).has_point(t):
				spawn_rooms.append(r)
				break
	var candidates: Array = []
	for r in rooms:
		if r in spawn_rooms:
			continue
		candidates.append(r)
	candidates.shuffle()
	var count := mini(3, maxi(2, candidates.size()))
	for i in count:
		var r: Dictionary = candidates[i]
		var center: Vector2i = r["center"]
		var pos := md.tile_center_world(center.x, center.y)
		md.objectives.append({
			"tile": center,
			"pos": pos,
			"radius": 2.6 * MapData.TILE_SIZE,
			"type": "device" if i == 0 else "objective",
			"room": r["tag"],
			"name": "obj_%d" % i,
		})
		# Loot sits next to the objective.
		var loot_tile := md.random_walkable_near(center, 2, rng)
		if loot_tile.x >= 0:
			md.loot.append({"tile": loot_tile, "pos": md.tile_center_world(loot_tile.x, loot_tile.y), "type": "loot"})


static func _place_evac(md: MapData, rng: RandomNumberGenerator, rooms: Array, cfg: Dictionary) -> void:
	var candidates: Array = rooms.duplicate()
	candidates.shuffle()
	var count := 2
	for i in mini(count, candidates.size()):
		var r: Dictionary = candidates[i]
		var center: Vector2i = r["center"]
		md.evac.append({
			"tile": center,
			"pos": md.tile_center_world(center.x, center.y),
			"radius": 2.8 * MapData.TILE_SIZE,
			"room": r["tag"],
		})


static func _place_lights(md: MapData, rng: RandomNumberGenerator, cfg: Dictionary, rooms: Array) -> void:
	var color_arr: Array = cfg.get("light_color", [0.7, 0.85, 0.8])
	var color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), 1.0)
	for r in rooms:
		var c: Vector2i = r["center"]
		md.lights.append({
			"pos": md.tile_center_world(c.x, c.y),
			"color": color,
			"energy": 1.15,
			"radius": 9.0 * MapData.TILE_SIZE,
			"flicker": rng.randf() < 0.14,
			"kind": "ceiling",
		})
	# Corridor lights.
	for i in range(0, md.width, 5):
		for j in range(0, md.height, 5):
			if md.tile_at(i, j) == MapData.Tile.FLOOR and rng.randf() < 0.22:
				md.lights.append({
					"pos": md.tile_center_world(i, j),
					"color": color.darkened(0.15),
					"energy": 0.5,
					"radius": 5.0 * MapData.TILE_SIZE,
					"flicker": rng.randf() < 0.1,
					"kind": "corridor",
				})
	# Neon accents near outside walls.
	if bool(cfg.get("outside", false)):
		for i in 8:
			var x := rng.randi_range(2, md.width - 3)
			var y := rng.randi_range(2, md.height - 3)
			var neon := Color(rng.randf(), 0.4 + rng.randf() * 0.4, 0.8, 1.0)
			md.lights.append({
				"pos": md.tile_center_world(x, y),
				"color": neon,
				"energy": 0.9,
				"radius": 6.0 * MapData.TILE_SIZE,
				"flicker": rng.randf() < 0.3,
				"kind": "neon",
			})


static func _place_props(md: MapData, rng: RandomNumberGenerator, cfg: Dictionary, rooms: Array) -> void:
	var theme: String = md.theme
	for r in rooms:
		var rect: Rect2i = r["rect"]
		var area := rect.size.x * rect.size.y
		var count := int(area / 26.0)
		count = clampi(count, 1, 9)
		for i in count:
			var tx := rng.randi_range(rect.position.x + 1, rect.position.x + rect.size.x - 2)
			var ty := rng.randi_range(rect.position.y + 1, rect.position.y + rect.size.y - 2)
			var tile := Vector2i(tx, ty)
			if not md.is_walkable(tx, ty):
				continue
			if _near_any(md.objectives, tile, 2) or _near_any(md.evac, tile, 2):
				continue
			if md.spawn_crim.has(tile) or md.spawn_cop.has(tile):
				continue
			var type := Props.random_for_theme(theme, rng)
			var def: Dictionary = Props.get_def(type)
			var w := int(def["w"])
			var h := int(def["h"])
			var half_tiles_x := int(ceil(w / MapData.TILE_SIZE / 2.0))
			var half_tiles_y := int(ceil(h / MapData.TILE_SIZE / 2.0))
			var ok := true
			for dy in range(-half_tiles_y, half_tiles_y + 1):
				for dx in range(-half_tiles_x, half_tiles_x + 1):
					var t := tile + Vector2i(dx, dy)
					if not md.is_walkable(t.x, t.y):
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var prop := {
				"type": type,
				"tile": tile,
				"pos": md.tile_center_world(tx, ty),
				"rot": 0.0 if rng.randf() < 0.7 else PI * 0.5,
				"tall": bool(def["tall"]),
			}
			md.props.append(prop)
			_mark_prop_tiles(md, prop, true)


static func _mark_prop_tiles(md: MapData, prop: Dictionary, value: bool) -> void:
	var def: Dictionary = Props.get_def(prop["type"])
	var half_x := int(ceil(float(def["w"]) / MapData.TILE_SIZE / 2.0))
	var half_y := int(ceil(float(def["h"]) / MapData.TILE_SIZE / 2.0))
	var tile: Vector2i = prop["tile"]
	for dy in range(-half_y, half_y + 1):
		for dx in range(-half_x, half_x + 1):
			var t := tile + Vector2i(dx, dy)
			if not md.in_bounds(t.x, t.y):
				continue
			var i := md.idx(t.x, t.y)
			md.blocked[i] = value
			if value and bool(def["tall"]):
				md.sight_block[i] = true


static func _near_any(list: Array, tile: Vector2i, radius: int) -> bool:
	for item in list:
		var t: Vector2i = item.get("tile", Vector2i(-999, -999))
		if abs(t.x - tile.x) <= radius and abs(t.y - tile.y) <= radius:
			return true
	return false


static func _validate(md: MapData) -> bool:
	var targets: Array = []
	for o in md.objectives:
		targets.append(o["tile"])
	for e in md.evac:
		targets.append(e["tile"])
	for l in md.loot:
		targets.append(l["tile"])
	targets.append_array(md.spawn_cop)
	if not md.all_reachable(md.spawn_crim, targets):
		# Props may have sealed a route: drop the newest props until it opens.
		var guard := 0
		while md.props.size() > 0 and guard < 60:
			guard += 1
			var prop: Dictionary = md.props.pop_back()
			_mark_prop_tiles(md, prop, false)
			if md.all_reachable(md.spawn_crim, targets):
				break
	return md.all_reachable(md.spawn_crim, targets)


# ----------------------------------------------------------------------------

static func _fallback(cfg: Dictionary, w: int, h: int, seed_value: int) -> MapData:
	## Deterministic, guaranteed-connected layout used when random generation
	## cannot produce a valid map.
	var md := MapData.new(w, h)
	md.theme = String(cfg.get("theme", "clinic"))
	md.seed_value = seed_value
	md.map_name = String(cfg.get("name", "map"))
	md.desc = String(cfg.get("description", ""))
	md.floor_texture = String(cfg.get("floor", "floor_concrete"))
	md.wall_texture = String(cfg.get("wall", "wall"))
	md.ambient = float(cfg.get("ambient", 0.3))
	var lc: Array = cfg.get("light_color", [0.7, 0.85, 0.8])
	md.light_color = Color(float(lc[0]), float(lc[1]), float(lc[2]), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# 3x3 room grid.
	var cols := 3
	var rows := 3
	var cell_w := (w - 8) / cols
	var cell_h := (h - 8) / rows
	var rooms: Array = []
	for cy in rows:
		for cx in cols:
			var rect := Rect2i(4 + cx * cell_w, 4 + cy * cell_h, cell_w - 2, cell_h - 2)
			rooms.append({"rect": rect, "tag": "room", "center": rect.get_center(), "floor_tiles": []})
			_carve_room(md, rooms[rooms.size() - 1], rng)
	# Grid corridors.
	for cx in cols:
		var x := 4 + cx * cell_w + cell_w / 2
		_carve_v(md, x, 4, h - 5, [])
	for cy in rows:
		var y := 4 + cy * cell_h + cell_h / 2
		_carve_h(md, y, 4, w - 5, [])
	_walls_around(md)
	_place_doors(md, rng, [_grid_paths(md)], rooms)
	_choose_spawns(md, rng, rooms)
	if md.spawn_crim.is_empty():
		md.spawn_crim = _free_tiles_in_room(md, rooms[0], 8)
	if md.spawn_cop.is_empty():
		md.spawn_cop = _free_tiles_in_room(md, rooms[rooms.size() - 1], 8)
	_place_objectives(md, rng, rooms, cfg)
	_place_evac(md, rng, rooms, cfg)
	_place_lights(md, rng, cfg, rooms)
	return md


static func _grid_paths(md: MapData) -> Array:
	var path: Array = []
	for y in md.height:
		for x in md.width:
			if md.tile_at(x, y) == MapData.Tile.FLOOR:
				path.append(Vector2i(x, y))
	return path
