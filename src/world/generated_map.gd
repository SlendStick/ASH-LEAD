class_name GeneratedMap
extends RefCounted
## Data container for a procedurally generated level.
##
## Everything the world builder, the AI navigation and the game modes need is
## serialised here as plain arrays/dictionaries so a map can be generated on the
## host, sent over the network and rebuilt on clients deterministically.

const TILE := 64
const VERSION := 1

# --- tile kinds ------------------------------------------------------------
const TK_VOID := 0        ## outside the playable area (solid)
const TK_FLOOR := 1       ## interior floor
const TK_STREET := 2      ## exterior walkable (asphalt / sidewalk / roof)
const TK_WALL := 3        ## solid wall
const TK_WINDOW := 4      ## blocks movement, not bullets fully (glass can break)
const TK_DOOR := 5        ## door slot (walkable when open)
const TK_GRATE := 6       ## low cover, blocks movement, bullets pass above
const TK_RAIL := 7        ## catwalk rail / glass barrier: see through, block walking
const TK_WATER := 8       ## puddle / flooded floor: slows, makes noise
const TK_CRATE := 9       ## furniture / full cover: blocks walking and bullets

const ROOM_NAMES := {
	"lobby": ["Лобби", "Приёмная", "Вестибюль", "Холл"],
	"office": ["Кабинет", "Бухгалтерия", "Отдел кадров", "Серверная"],
	"vault": ["Хранилище", "Сейфовая", "Депонирование"],
	"corridor": ["Коридор", "Переход", "Галерея"],
	"storage": ["Склад", "Подсобка", "Архив", "Морг"],
	"security": ["Пульт охраны", "Наблюдение", "Комната камер"],
	"ward": ["Палата", "Процедурная", "Операционная"],
	"shop": ["Магазин", "Бутик", "Павильон"],
	"hall": ["Зал", "Атриум", "Сцена"],
	"kitchen": ["Кухня", "Столовая", "Бар"],
	"classroom": ["Класс", "Аудитория", "Кабинет труда"],
	"cell": ["Камера", "КПЗ", "Допросная"],
	"yard": ["Двор", "Парковка", "Погрузка"],
	"roof": ["Крыша", "Вентиляция", "Техэтаж"],
	"vip": ["Кабинет директора", "Пентхаус", "Приёмная мэра"],
	"hostage": ["Комната отдыха", "Кассовый зал", "Учительская"],
}

var theme_id: String = "asphalt_night"
var theme: Dictionary = {}
var mode_id: String = "deathmatch"
var seed_value: int = 0
var w: int = 48
var h: int = 36
var tiles: PackedByteArray = PackedByteArray()
var rooms: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var windows: Array[Vector2i] = []
var props: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var spawns_crim: Array[Vector2i] = []
var spawns_police: Array[Vector2i] = []
var spawns_civ: Array[Vector2i] = []
var points: Dictionary = {}
var patrols: Array = []
var cover: Array[Vector2i] = []
var name: String = ""

# --- helpers ---------------------------------------------------------------

func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func tile_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return TK_VOID
	return tiles[idx(c)]


func set_tile(c: Vector2i, t: int) -> void:
	if in_bounds(c):
		tiles[idx(c)] = t


## Alias used by interactive props (doors) that temporarily seal a tile.
func set_tile_cell(c: Vector2i, t: int) -> void:
	set_tile(c, t)


func is_solid(c: Vector2i) -> bool:
	var t := tile_at(c)
	return t == TK_VOID or t == TK_WALL or t == TK_WINDOW or t == TK_GRATE


func is_wall_like(c: Vector2i) -> bool:
	var t := tile_at(c)
	return t == TK_VOID or t == TK_WALL or t == TK_WINDOW


func blocks_vision(c: Vector2i) -> bool:
	var t := tile_at(c)
	return t == TK_VOID or t == TK_WALL


func walkable(c: Vector2i) -> bool:
	var t := tile_at(c)
	return t == TK_FLOOR or t == TK_STREET or t == TK_DOOR or t == TK_WATER


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE)), int(floor(p.y / TILE)))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(c.x * TILE, c.y * TILE, TILE, TILE)


func world_size() -> Vector2:
	return Vector2(w * TILE, h * TILE)


func room_count() -> int:
	return rooms.size()


func random_floor(rng: RandomNumberGenerator, team: int = 0, near_room: int = -1) -> Vector2:
	var pool: Array[Vector2i] = []
	if near_room >= 0 and near_room < rooms.size():
		var r: Dictionary = rooms[near_room]
		var rect: Rect2i = r["rect"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				if walkable(c):
					pool.append(c)
	else:
		for i in range(tiles.size()):
			if tiles[i] == TK_FLOOR:
				pool.append(Vector2i(i % w, i / w))
	if pool.is_empty():
		return cell_to_world(Vector2i(w / 2, h / 2))
	var c2 := pool[rng.randi_range(0, pool.size() - 1)]
	return cell_to_world(c2)


func nearest_room(at: Vector2) -> int:
	var c := world_to_cell(at)
	var best := -1
	var best_d := 1e9
	for i in range(rooms.size()):
		var rect: Rect2i = rooms[i]["rect"]
		if rect.has_point(c):
			return i
		var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
		var d := center.distance_squared_to(Vector2(c))
		if d < best_d:
			best_d = d
			best = i
	return best


func room_at_cell(c: Vector2i) -> int:
	for i in range(rooms.size()):
		var rect: Rect2i = rooms[i]["rect"]
		if rect.has_point(c):
			return i
	return -1


func room_name(room_index: int) -> String:
	if room_index < 0 or room_index >= rooms.size():
		return "Улица"
	return str(rooms[room_index].get("name", "Комната"))


func is_interior() -> bool:
	return str(theme.get("type", "")) != "street" and str(theme.get("type", "")) != "roof"


func door_at(c: Vector2i) -> int:
	for i in range(doors.size()):
		var d: Dictionary = doors[i]
		if d["cell"] == c or d.get("cell_b", c) == c:
			return i
	return -1


## Serialise to a compact dictionary (for network transfer / replay seeds).
func to_dict() -> Dictionary:
	return {
		"theme": theme_id, "mode": mode_id, "seed": seed_value, "w": w, "h": h,
		"rooms": rooms, "doors": doors, "props": props, "lights": lights,
		"points": points, "name": name,
	}


## Rebuild only the deterministic structure from a seed (tiles are regenerated).
static func from_seed(theme: String, seed_val: int, mode: String) -> GeneratedMap:
	var g := MapGen.generate(theme, seed_val, mode)
	return g


# ---------------------------------------------------------------------------
# CACHED LOOKUPS
# ---------------------------------------------------------------------------
# tile_at() is called thousands of times per frame (bullets, LOS, AI pathing,
# fog). The bounds test plus PackedByteArray index is fast, but the visibility
# and smoke queries repeat the same cells, so a small per-cell cache lives here.

var _solid_cache := PackedByteArray()
var _vision_cache := PackedByteArray()


func build_caches() -> void:
	_solid_cache.resize(tiles.size())
	_vision_cache.resize(tiles.size())
	for i in range(tiles.size()):
		var t := tiles[i]
		_solid_cache[i] = 1 if (t == TK_VOID or t == TK_WALL or t == TK_WINDOW or t == TK_GRATE or t == TK_CRATE) else 0
		_vision_cache[i] = 1 if (t == TK_VOID or t == TK_WALL or t == TK_CRATE) else 0


## True when the tile stops movement (walls, crater edges, windows, crates).
func solid_at(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	if _solid_cache.size() != tiles.size():
		return is_solid(c)
	return _solid_cache[idx(c)] == 1


## True when the tile stops line of sight.
func opaque_at(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	if _vision_cache.size() != tiles.size():
		return blocks_vision(c)
	return _vision_cache[idx(c)] == 1


## Keep the caches in sync after MapGen edits the grid (doors sealing tiles).
func refresh_cell(c: Vector2i) -> void:
	if not in_bounds(c) or _solid_cache.size() != tiles.size():
		return
	var t := tiles[idx(c)]
	_solid_cache[idx(c)] = 1 if (t == TK_VOID or t == TK_WALL or t == TK_WINDOW or t == TK_GRATE or t == TK_CRATE) else 0
	_vision_cache[idx(c)] = 1 if (t == TK_VOID or t == TK_WALL or t == TK_CRATE) else 0


## Number of cells we can walk on -- used by the map validator and the bots'
## "is there somewhere to go" check.
func walkable_count() -> int:
	var n := 0
	for i in range(tiles.size()):
		if _solid_cache.size() == tiles.size():
			if _solid_cache[i] == 0:
				n += 1
		elif not is_solid(Vector2i(i % w, i / w)):
			n += 1
	return n


## Playable bounds in world space (used by the camera limits and the fog quad).
var bounds := Rect2()
## Every walkable cell, precomputed: spawn picking and "is there anywhere to go"
## checks no longer scan the whole grid.
var walkable_cells: Array[Vector2i] = []


func compute_bounds() -> void:
	bounds = Rect2(0, 0, w * TILE, h * TILE)
	walkable_cells.clear()
	for y in range(h):
		for x in range(w):
			var c := Vector2i(x, y)
			if walkable(c):
				walkable_cells.append(c)
