class_name MapData
extends RefCounted
## Tile grid, rooms, objectives and pathfinding for one generated map.

const TILE_SIZE := 64.0

enum Tile {
	VOID = 0,
	FLOOR = 1,
	WALL = 2,
	DOOR = 3,
	GLASS = 4,
	COVER = 5,
	OUTSIDE = 6,
	ROAD = 7,
	GRATE = 8,
	PUDDLE = 9,
}

var width: int = 0
var height: int = 0
var tiles: Array = []
var variant: Array = []
var blocked: Array = []       # movement blocked by props
var sight_block: Array = []   # tall props / walls block line of sight
var theme: String = ""
var seed_value: int = 0
var map_name: String = ""
var desc: String = ""
var floor_texture: String = "floor_concrete"
var wall_texture: String = "wall"
var ambient: float = 0.3
var light_color: Color = Color(0.7, 0.85, 0.8)
var rooms: Array = []
var spawn_crim: Array = []
var spawn_cop: Array = []
var objectives: Array = []
var evac: Array = []
var loot: Array = []
var civil_spawns: Array = []
var doors: Array = []
var lights: Array = []
var props: Array = []
var door_map: Dictionary = {}
var light_level: Array = []


func _init(map_width: int = 0, map_height: int = 0) -> void:
	width = map_width
	height = map_height
	var count := width * height
	tiles = []
	variant = []
	blocked = []
	sight_block = []
	light_level = []
	for i in count:
		tiles.append(Tile.VOID)
		variant.append(0)
		blocked.append(false)
		sight_block.append(false)
		light_level.append(0.0)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func idx(x: int, y: int) -> int:
	return y * width + x


func set_tile(x: int, y: int, tile: int, variant_id: int = 0) -> void:
	if not in_bounds(x, y):
		return
	var i := idx(x, y)
	tiles[i] = tile
	variant[i] = variant_id
	if tile == Tile.WALL:
		sight_block[i] = true
	elif tile == Tile.DOOR:
		sight_block[i] = true
	elif tile == Tile.GLASS:
		sight_block[i] = false
	else:
		sight_block[i] = false


func tile_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tile.VOID
	return int(tiles[idx(x, y)])


func is_walkable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var i := idx(x, y)
	if blocked[i]:
		return false
	var t := int(tiles[i])
	match t:
		Tile.FLOOR, Tile.OUTSIDE, Tile.ROAD, Tile.GRATE, Tile.PUDDLE:
			return true
		Tile.DOOR:
			# Doors are passable for pathfinding: characters open them on
			# contact (see Match.open_doors_near). Closed doors still block
			# line of sight and bullets.
			return true
		_:
			return false


func blocks_sight(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return bool(sight_block[idx(x, y)])


func blocks_bullets(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	var i := idx(x, y)
	if bool(sight_block[i]):
		return true
	var t := int(tiles[i])
	if t == Tile.WALL or t == Tile.GLASS:
		return true
	if t == Tile.DOOR:
		var door: Variant = door_map.get(Vector2i(x, y))
		return not (bool(door.get("open", false)) if door is Dictionary else false)
	return false


func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE_SIZE)), int(floor(pos.y / TILE_SIZE)))


func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x + 0.5, tile.y + 0.5) * TILE_SIZE


func tile_center_world(x: int, y: int) -> Vector2:
	return Vector2(x + 0.5, y + 0.5) * TILE_SIZE


## Line of sight between two world positions (tile sampling).
func has_los(a: Vector2, b: Vector2) -> bool:
	var ta := world_to_tile(a)
	var tb := world_to_tile(b)
	if ta == tb:
		return true
	for p in U.bresenham(ta, tb):
		if blocks_sight(p.x, p.y):
			return false
	return true


## BFS path on the walkable grid, returned as world positions (smoothed).
func find_path(from_world: Vector2, to_world: Vector2) -> Array:
	var start := world_to_tile(from_world)
	var goal := world_to_tile(to_world)
	if not in_bounds(start.x, start.y) or not in_bounds(goal.x, goal.y):
		return []
	if start == goal:
		return [to_world]
	if not is_walkable(goal.x, goal.y):
		goal = _nearest_walkable(goal)
		if goal.x < 0:
			return []
	var came := {}
	var queue: Array = [start]
	came[start] = start
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			if not is_walkable(nxt.x, nxt.y):
				continue
			if came.has(nxt):
				continue
			came[nxt] = cur
			queue.append(nxt)
	if not came.has(goal):
		return []
	var path: Array = []
	var cur2: Vector2i = goal
	while cur2 != start:
		path.append(tile_center_world(cur2.x, cur2.y))
		cur2 = came[cur2]
	path.append(from_world)
	path.reverse()
	path.append(to_world)
	return _smooth_path(path)


func _smooth_path(path: Array) -> Array:
	if path.size() <= 2:
		return path
	var out: Array = [path[0]]
	var i := 0
	while i < path.size() - 1:
		var j := path.size() - 1
		while j > i + 1:
			if _los_world(path[i], path[j]):
				break
			j -= 1
		out.append(path[j])
		i = j
	return out


func _los_world(a: Vector2, b: Vector2) -> bool:
	return has_los(a, b)


func _nearest_walkable(tile: Vector2i) -> Vector2i:
	for radius in range(1, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var n := tile + Vector2i(dx, dy)
				if is_walkable(n.x, n.y):
					return n
	return Vector2i(-1, -1)


func random_walkable_near(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> Vector2i:
	for i in 24:
		var t := center + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
		if is_walkable(t.x, t.y):
			return t
	return Vector2i(-1, -1)


## Breadth-first reachability check between a set of tiles and targets.
func all_reachable(from_tiles: Array, targets: Array) -> bool:
	if from_tiles.is_empty() or targets.is_empty():
		return false
	var start: Vector2i = from_tiles[0]
	var visited := {start: true}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			if not is_walkable(nxt.x, nxt.y) or visited.has(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)
	for t in targets:
		var tt: Vector2i = t
		if not visited.has(tt):
			return false
	return true


func room_at(tile: Vector2i) -> Dictionary:
	for r in rooms:
		var rect: Rect2i = r.get("rect", Rect2i())
		if rect.has_point(tile):
			return r
	return {}
