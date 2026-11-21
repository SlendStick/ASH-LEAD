class_name WallPainter
extends Node2D
## Draws walls with neon-noir lighting: dark masses, emissive trims, wet streaks,
## glass windows, girders and signage on the facade. Runs as a child of the
## static physics body so it never has to be moved.

## tile size in pixels (mirrors GeneratedMap.TILE; class consts are not const-expressions)
const T := 64

var map: GeneratedMap


func _ready() -> void:
	if map != null:
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var accent := Color(str(map.theme.get("accent", "#ff2b62")))
	var accent2 := Color(str(map.theme.get("accent2", "#35c9ff")))
	var pal: Array = map.theme.get("palette", ["#0d0d16", "#1b1a2b", "#221d33"])
	var wall_col := Color(str(pal[2]))
	var edge_col := Color(str(pal[1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value + 99

	# 1. merged wall masses with depth offsets
	for y in range(map.h):
		var x := 0
		while x < map.w:
			var c := Vector2i(x, y)
			var t := map.tile_at(c)
			if t != GeneratedMap.TK_WALL and t != GeneratedMap.TK_VOID:
				x += 1
				continue
			var run := 1
			while x + run < map.w and map.tile_at(Vector2i(x + run, y)) == t:
				run += 1
			var base := Color(0.0235, 0.0235, 0.0353) if t == GeneratedMap.TK_VOID else wall_col
			draw_rect(Rect2(x * T, y * T, run * T, T), base, true)
			# top highlight
			draw_rect(Rect2(x * T, y * T, run * T, 3), base.lightened(0.18), true)
			# bottom shadow
			draw_rect(Rect2(x * T, y * T + T - 6, run * T, 6), Color(0, 0, 0, 0.45), true)
			x += run

	# 2. per-wall detail: bricks, wet streaks, pipes, air conditioners, trims
	for y in range(map.h):
		for x in range(map.w):
			var c2 := Vector2i(x, y)
			var tt := map.tile_at(c2)
			var p := Vector2(x * T, y * T)
			if tt == GeneratedMap.TK_WALL:
				_wall_detail(p, c2, edge_col, rng)
				# emissive edge trims where a wall faces walkable floor
				if _open_neighbor(c2, Vector2i(0, -1)):
					draw_rect(Rect2(p, Vector2(T, 2)), Color(accent.r, accent.g, accent.b, 0.20), true)
				if _open_neighbor(c2, Vector2i(0, 1)):
					draw_rect(Rect2(p + Vector2(0, T - 2), Vector2(T, 2)), Color(accent.r, accent.g, accent.b, 0.12), true)
				if _open_neighbor(c2, Vector2i(-1, 0)):
					draw_rect(Rect2(p, Vector2(2, T)), Color(accent2.r, accent2.g, accent2.b, 0.13), true)
			elif tt == GeneratedMap.TK_WINDOW:
				_window(p, c2, accent2, rng)

	# 3. facade neon strips every few tiles along the street side
	if map.is_interior():
		for y in range(3, map.h - 3, 6):
			for x in range(3, map.w - 3, 9):
				if map.tile_at(Vector2i(x, y)) == GeneratedMap.TK_WALL and map.tile_at(Vector2i(x, y + 1)) != GeneratedMap.TK_WALL:
					draw_line(Vector2(x * T + 6, y * T + T - 5), Vector2(x * T + T * 2, y * T + T - 5), Color(accent.r, accent.g, accent.b, 0.35), 2.0)

	# 4. big painted graffiti / mural on random street walls
	for i in range(8):
		var c3 := Vector2i(rng.randi_range(2, map.w - 3), rng.randi_range(2, map.h - 3))
		if map.tile_at(c3) != GeneratedMap.TK_WALL:
			continue
		if not _open_neighbor(c3, Vector2i(0, 1)):
			continue
		_graffiti(Vector2(c3) * T, rng)


func _open_neighbor(c: Vector2i, d: Vector2i) -> bool:
	var t := map.tile_at(c + d)
	return t == GeneratedMap.TK_FLOOR or t == GeneratedMap.TK_STREET or t == GeneratedMap.TK_DOOR


func _wall_detail(p: Vector2, c: Vector2i, edge: Color, rng: RandomNumberGenerator) -> void:
	var h2 := int(abs(hash(c) % 6))
	if h2 == 0:
		# brick rows
		for i in range(3):
			draw_line(p + Vector2(0, 18 + i * 16), p + Vector2(T, 18 + i * 16), Color(0, 0, 0, 0.35), 1.0)
		draw_line(p + Vector2(T * 0.5, 0), p + Vector2(T * 0.5, 18), Color(0, 0, 0, 0.25), 1.0)
	elif h2 == 1:
		draw_circle(p + Vector2(T * 0.5, T * 0.35), 5.0, Color(0, 0, 0, 0.4))
		draw_line(p + Vector2(T * 0.5, T * 0.4), p + Vector2(T * 0.5, T * 0.9), Color(0, 0, 0, 0.3), 2.0)
	elif h2 == 2:
		draw_rect(Rect2(p + Vector2(20, 12), Vector2(24, 18)), Color(0, 0, 0, 0.3), true)
		draw_rect(Rect2(p + Vector2(20, 12), Vector2(24, 18)), Color(edge.r, edge.g, edge.b, 0.4), false, 1.0)
	elif h2 == 3:
		# wet streak running down
		draw_line(p + Vector2(rng.randf_range(10, 50), 0), p + Vector2(rng.randf_range(10, 50), T), Color(0.5, 0.8, 1.0, 0.05), 3.0)


func _window(p: Vector2, c: Vector2i, accent: Color, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.0392, 0.0863, 0.1333), true)
	# frame
	draw_rect(Rect2(p + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(0.1059, 0.149, 0.2039), false, 3.0)
	# glass gradient
	var lit := int(abs(hash(c) % 3)) == 0
	if lit:
		draw_rect(Rect2(p + Vector2(6, 6), Vector2(T - 12, T - 12)), Color(accent.r, accent.g, accent.b, 0.10), true)
	else:
		draw_rect(Rect2(p + Vector2(6, 6), Vector2(T - 12, T - 12)), Color(0.2, 0.4, 0.6, 0.05), true)
	# crack / reflection
	draw_line(p + Vector2(10, 8), p + Vector2(T - 12, T - 10), Color(1, 1, 1, 0.09), 1.0)
	if rng.randf() < 0.12:
		draw_line(p + Vector2(12, T - 12), p + Vector2(T * 0.5, T * 0.4), Color(0.9, 0.95, 1.0, 0.25), 1.0)
		draw_line(p + Vector2(T * 0.5, T * 0.4), p + Vector2(T - 14, T - 8), Color(0.9, 0.95, 1.0, 0.18), 1.0)


func _graffiti(p: Vector2, rng: RandomNumberGenerator) -> void:
	var col := Color(["#ff2b62", "#8d2bff", "#2bff9a", "#35c9ff"][rng.randi_range(0, 3)])
	col.a = 0.35
	var x := p.x + 8
	for i in range(rng.randi_range(3, 5)):
		var pts := PackedVector2Array()
		for k in range(4):
			pts.append(Vector2(x + k * 9, p.y + rng.randf_range(10, 50)))
		draw_polyline(pts, col, 3.0)
		x += 18
