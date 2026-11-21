class_name FloorPainter
extends Node2D
## Bakes the level floor into a single static canvas item.
## Wet asphalt, cold interior stone, carpet, tiles, grates, rails and water.

## tile size in pixels (mirrors GeneratedMap.TILE; class consts are not const-expressions)
const T := 64

var map: GeneratedMap

const FLOOR_PALETTES := {
	"street": [Color(0.0784, 0.0784, 0.1255), Color(0.0627, 0.0627, 0.0941), Color(0.0941, 0.0941, 0.149)],
	"roof": [Color(0.0784, 0.0941, 0.1294), Color(0.0667, 0.0824, 0.1255), Color(0.102, 0.1216, 0.1686)],
	"hospital": [Color(0.102, 0.1647, 0.1804), Color(0.0863, 0.149, 0.1647), Color(0.1255, 0.2039, 0.2275)],
	"warehouse": [Color(0.1059, 0.1059, 0.1098), Color(0.0863, 0.0863, 0.0902), Color(0.1373, 0.1373, 0.1333)],
	"school": [Color(0.098, 0.1373, 0.1765), Color(0.0824, 0.1216, 0.1569), Color(0.1216, 0.1686, 0.2118)],
	"cinema": [Color(0.1373, 0.0745, 0.1333), Color(0.1098, 0.0588, 0.1098), Color(0.1725, 0.102, 0.1647)],
	"mall": [Color(0.0941, 0.0941, 0.1373), Color(0.0784, 0.0784, 0.1176), Color(0.1216, 0.1216, 0.1725)],
	"bank": [Color(0.0824, 0.1059, 0.1412), Color(0.0667, 0.0863, 0.1176), Color(0.1137, 0.1412, 0.1804)],
	"precinct": [Color(0.0667, 0.098, 0.1529), Color(0.0549, 0.0784, 0.1216), Color(0.0941, 0.1333, 0.2078)],
	"subway": [Color(0.0706, 0.0824, 0.1137), Color(0.0588, 0.0706, 0.098), Color(0.0941, 0.1098, 0.149)],
	"penthouse": [Color(0.0902, 0.0745, 0.1451), Color(0.0745, 0.0627, 0.1255), Color(0.1216, 0.098, 0.1882)],
	"shop": [Color(0.1412, 0.102, 0.0706), Color(0.1176, 0.0824, 0.0588), Color(0.1725, 0.1255, 0.0863)],
}


func _ready() -> void:
	if map != null:
		queue_redraw()


func _palette() -> Array:
	var t := str(map.theme.get("type", "street"))
	return FLOOR_PALETTES.get(t, FLOOR_PALETTES["street"])


func _draw() -> void:
	if map == null:
		return
	var pal := _palette()
	var accent := Color(str(map.theme.get("accent", "#ff2b62")))
	var accent2 := Color(str(map.theme.get("accent2", "#35c9ff")))
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value

	# 1. base plates, run-merged per palette shade
	for y in range(map.h):
		var x := 0
		while x < map.w:
			var c := Vector2i(x, y)
			var t := map.tile_at(c)
			if t == GeneratedMap.TK_VOID:
				x += 1
				continue
			var shade := int(abs(hash(Vector2i(c.x / 3, c.y / 3)) % 3))
			var col: Color = pal[shade]
			var run := 1
			while x + run < map.w:
				var cc := Vector2i(x + run, y)
				if map.tile_at(cc) != t:
					break
				if int(abs(hash(Vector2i(cc.x / 3, cc.y / 3)) % 3)) != shade:
					break
				run += 1
			if t == GeneratedMap.TK_VOID:
				x += run
				continue
			draw_rect(Rect2(x * T, y * T, run * T, T), col, true)
			x += run

	# 2. surface detail
	for y in range(map.h):
		for x in range(map.w):
			var c2 := Vector2i(x, y)
			var tt := map.tile_at(c2)
			var p := Vector2(x * T, y * T)
			match tt:
				GeneratedMap.TK_FLOOR:
					_inner_floor(p, c2, pal, accent, accent2, rng)
				GeneratedMap.TK_STREET:
					_street(p, c2, rng)
				GeneratedMap.TK_WATER:
					_water(p, c2, rng)
				GeneratedMap.TK_GRATE:
					_grate(p, c2)
				GeneratedMap.TK_RAIL:
					_rail(p, c2, accent2)
				GeneratedMap.TK_DOOR:
					_doorway(p, c2, accent)
				GeneratedMap.TK_CRATE:
					draw_rect(Rect2(p + Vector2(6, 6), Vector2(T - 12, T - 12)), Color(0.1647, 0.1412, 0.098), true)
					draw_rect(Rect2(p + Vector2(6, 6), Vector2(T - 12, T - 12)), Color(0.2902, 0.2471, 0.1569), false, 2.0)

	# 3. room accents: rugs, carpets, painted lines, blood pools from the theme
	for i in range(map.rooms.size()):
		var room: Dictionary = map.rooms[i]
		var r: Rect2i = room["rect"]
		var kind := str(room["kind"])
		var inner := Rect2((Vector2(r.position) + Vector2(1.5, 1.5)) * T, (Vector2(r.size) - Vector2(3, 3)) * T)
		var tint := Color(accent)
		tint.a = 0.05
		if kind == "vault":
			draw_rect(inner, Color(1.0, 0.75, 0.2, 0.06), true)
		elif kind == "hall":
			draw_rect(inner, Color(accent2.r, accent2.g, accent2.b, 0.06), true)
		elif kind == "hostage":
			draw_rect(inner, Color(1.0, 0.1, 0.3, 0.07), true)
		else:
			draw_rect(inner, tint, true)
		# painted floor line / hazard stripe for service rooms
		if kind == "storage" or kind == "yard":
			var y2 := inner.position.y + inner.size.y - 18
			draw_line(Vector2(inner.position.x + 10, y2), Vector2(inner.position.x + inner.size.x - 10, y2), Color(1.0, 0.6902, 0.1686, 0.4), 3.0)


func _inner_floor(p: Vector2, c: Vector2i, pal: Array, accent: Color, accent2: Color, rng: RandomNumberGenerator) -> void:
	var base: Color = pal[0]
	var h2 := int(abs(hash(Vector2i(c.x / 2, c.y / 2)) % 5))
	if h2 == 0:
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(T - 4, T - 4)), base.lightened(0.06), true)
	# tile seams
	draw_line(p + Vector2(0, 0.5), p + Vector2(T, 0.5), Color(0, 0, 0, 0.35), 1.0)
	draw_line(p + Vector2(0.5, 0), p + Vector2(0.5, T), Color(0, 0, 0, 0.35), 1.0)
	# occasional reflective floor patch (wet linoleum / marble)
	if h2 == 1:
		var g := accent2
		g.a = 0.05
		draw_rect(Rect2(p + Vector2(8, 8), Vector2(T - 16, T - 16)), g, true)
	# grime
	if h2 == 3:
		draw_circle(p + Vector2(T * 0.6, T * 0.4), 5.0, Color(0, 0, 0, 0.25))
	if rng.randf() < 0.02:
		draw_circle(p + Vector2(rng.randf_range(6, 58), rng.randf_range(6, 58)), rng.randf_range(2, 5), Color(0.45, 0.02, 0.08, 0.35))


func _street(p: Vector2, c: Vector2i, rng: RandomNumberGenerator) -> void:
	# asphalt grain + road markings + reflection streaks
	var h2 := int(abs(hash(c) % 7))
	if h2 == 0:
		draw_rect(Rect2(p + Vector2(4, 4), Vector2(T - 8, T - 8)), Color(1, 1, 1, 0.012), true)
	if h2 == 2:
		draw_line(p + Vector2(6, 52), p + Vector2(T - 6, 48), Color(0, 0, 0, 0.3), 1.0)
	# sidewalk check pattern near the building side
	if rng.randf() < 0.05:
		draw_rect(Rect2(p + Vector2(0, 0), Vector2(T, 6)), Color(0.2275, 0.2275, 0.2902), true)
	# puddle glints
	if h2 == 3:
		draw_circle(p + Vector2(T * 0.5, T * 0.55), 18.0, Color(0.15, 0.35, 0.55, 0.05))


func _water(p: Vector2, c: Vector2i, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.0431, 0.0863, 0.149), true)
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.2, 0.5, 0.9, 0.06), true)
	for i in range(2):
		var y2 := p.y + rng.randf_range(8, 56)
		draw_line(Vector2(p.x + 4, y2), Vector2(p.x + T - 4, y2 + rng.randf_range(-3, 3)), Color(0.4, 0.7, 1.0, 0.10), 1.0)


func _grate(p: Vector2, c: Vector2i) -> void:
	var col := Color(0.1647, 0.1647, 0.2118)
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.0706, 0.0706, 0.0941), true)
	for i in range(4):
		draw_line(p + Vector2(4, 10 + i * 14), p + Vector2(T - 4, 10 + i * 14), col, 3.0)
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.2392, 0.2392, 0.302), false, 2.0)


func _rail(p: Vector2, c: Vector2i, accent: Color) -> void:
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.0627, 0.0627, 0.0941), true)
	draw_line(p + Vector2(0, T * 0.5), p + Vector2(T, T * 0.5), Color(accent.r, accent.g, accent.b, 0.5), 2.0)


func _doorway(p: Vector2, c: Vector2i, accent: Color) -> void:
	# threshold strip so doors read as openings
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.0824, 0.0824, 0.1216), true)
	draw_line(p + Vector2(0, 4), p + Vector2(T, 4), Color(accent.r, accent.g, accent.b, 0.25), 2.0)
	draw_line(p + Vector2(0, T - 4), p + Vector2(T, T - 4), Color(accent.r, accent.g, accent.b, 0.25), 2.0)
