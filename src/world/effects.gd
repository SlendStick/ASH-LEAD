class_name Effects
extends Node2D
## Purely cosmetic particles: blood, sparks, dust, smoke clouds, fire, explosion
## rings, floating damage numbers, brass casings and shell bursts. Everything is
## procedural and pooled by simple lifetime; the effects node never blocks AI or
## physics.

var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var smoke_clouds: Array[Dictionary] = []
var fires: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var map: GeneratedMap
var t := 0.0
var vision_world: Node = null


func _ready() -> void:
	z_index = 25
	rng.seed = 9001


func bleeds(pos: Vector2, dir: Vector2, amount: float) -> void:
	var count := int(6 + amount * 10)
	for i in range(count):
		var ang := dir.angle() + rng.randf_range(-0.7, 0.7)
		var spd := rng.randf_range(60.0, 260.0) * (0.5 + amount * 0.5)
		particles.append({
			"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": rng.randf_range(0.2, 0.55), "max": 0.55,
			"size": rng.randf_range(1.5, 4.5), "color": Color(0.55, 0.02, 0.08),
			"dist": 0.0,
		})


func sparks(pos: Vector2, normal: Vector2, kind: String = "wall") -> void:
	var col := Color(1.0, 0.85, 0.5)
	var count := 5 if kind == "wall" else 3
	for i in range(count):
		var ang := normal.angle() + rng.randf_range(-1.0, 1.0)
		particles.append({
			"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * rng.randf_range(80, 300),
			"life": rng.randf_range(0.1, 0.3), "max": 0.3,
			"size": rng.randf_range(1.0, 2.2), "color": col, "dist": 0.0,
		})


func dust(pos: Vector2, normal: Vector2) -> void:
	for i in range(4):
		var ang := normal.angle() + rng.randf_range(-1.2, 1.2)
		particles.append({
			"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * rng.randf_range(20, 90),
			"life": rng.randf_range(0.3, 0.8), "max": 0.8,
			"size": rng.randf_range(2.0, 5.0), "color": Color(0.55, 0.52, 0.48, 0.5), "dist": 0.0,
		})


func casing(pos: Vector2, dir: Vector2) -> void:
	var side := dir.rotated(PI * 0.5)
	particles.append({
		"pos": pos, "vel": side * rng.randf_range(40, 130) + dir * rng.randf_range(-20, 20),
		"life": 0.7, "max": 0.7, "size": 2.0, "color": Color(0.78, 0.64, 0.28), "dist": 0.0,
	})


func explosion(pos: Vector2, radius: float) -> void:
	rings.append({"pos": pos, "life": 0.6, "max": 0.6, "radius": radius})
	for i in range(26):
		var ang := rng.randf_range(0.0, TAU)
		var spd := rng.randf_range(120.0, radius * 2.2)
		particles.append({
			"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": rng.randf_range(0.2, 0.7), "max": 0.7,
			"size": rng.randf_range(2.0, 6.0),
			"color": Color(1.0, 0.55, 0.15) if i % 3 != 0 else Color(1.0, 0.9, 0.6),
			"dist": 0.0,
		})
	for i in range(10):
		smoke_clouds.append({"pos": pos + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)),
			"life": 4.0, "max": 4.0, "radius": rng.randf_range(30, 70), "grow": 40.0,
			"color": Color(0.22, 0.2, 0.24)})


func smoke(pos: Vector2, radius: float, seconds: float) -> void:
	for i in range(12):
		smoke_clouds.append({
			"pos": pos + Vector2(rng.randf_range(-radius * 0.5, radius * 0.5), rng.randf_range(-radius * 0.5, radius * 0.5)),
			"life": seconds, "max": seconds, "radius": radius * 0.35, "grow": radius / seconds * 0.8,
			"color": Color(0.5, 0.52, 0.56),
		})


func fire(pos: Vector2, radius: float, seconds: float) -> void:
	fires.append({"pos": pos, "life": seconds, "max": seconds, "radius": radius})


func flash(pos: Vector2, radius: float, color: Color) -> void:
	rings.append({"pos": pos, "life": 0.35, "max": 0.35, "radius": radius, "color": color})


func damage_number(pos: Vector2, amount: float, kind: String) -> void:
	texts.append({
		"pos": pos + Vector2(rng.randf_range(-10, 10), -20), "life": 0.9, "max": 0.9,
		"text": str(int(amount)), "color": Color(1.0, 0.85, 0.6) if kind != "head" else Color(1.0, 0.35, 0.4),
	})


func _process(delta: float) -> void:
	t += delta
	var keep: Array[Dictionary] = []
	for p in particles:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			continue
		if map != null:
			var cur: Vector2 = p["pos"]
			var v: Vector2 = p["vel"]
			var nxt := cur + v * delta
			var cell := map.world_to_cell(Vector2(nxt.x, cur.y))
			if map.is_solid(cell):
				v.x = -v.x * 0.3
			else:
				cur.x = nxt.x
			var cell2 := map.world_to_cell(Vector2(cur.x, cur.y + v.y * delta))
			if map.is_solid(cell2):
				v.y = -v.y * 0.3
			else:
				cur.y += v.y * delta
			p["pos"] = cur
			p["vel"] = v * (1.0 - delta * 4.0)
		else:
			p["pos"] = p["pos"] + p["vel"] * delta
		keep.append(p)
	particles = keep
	var keep_rings: Array[Dictionary] = []
	for r in rings:
		r["life"] = float(r["life"]) - delta
		if float(r["life"]) > 0.0:
			keep_rings.append(r)
	rings = keep_rings
	var keep_texts: Array[Dictionary] = []
	for tx in texts:
		tx["life"] = float(tx["life"]) - delta
		tx["pos"] = tx["pos"] + Vector2(0, -40.0 * delta)
		if float(tx["life"]) > 0.0:
			keep_texts.append(tx)
	texts = keep_texts
	var keep_smoke: Array[Dictionary] = []
	for s in smoke_clouds:
		s["life"] = float(s["life"]) - delta
		s["radius"] = float(s["radius"]) + float(s["grow"]) * delta
		if float(s["life"]) > 0.0:
			keep_smoke.append(s)
	smoke_clouds = keep_smoke
	var keep_fire: Array[Dictionary] = []
	for f in fires:
		f["life"] = float(f["life"]) - delta
		if float(f["life"]) > 0.0:
			keep_fire.append(f)
	fires = keep_fire
	queue_redraw()


func _draw() -> void:
	# smoke
	for s in smoke_clouds:
		var a := clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		var c: Color = s["color"]
		draw_circle(s["pos"], float(s["radius"]), Color(c.r, c.g, c.b, 0.16 * a))
		draw_circle(s["pos"], float(s["radius"]) * 0.7, Color(c.r, c.g, c.b, 0.14 * a))
	# fires
	for f in fires:
		var a2 := clampf(float(f["life"]) / float(f["max"]), 0.0, 1.0)
		var rad := float(f["radius"])
		draw_circle(f["pos"], rad, Color(1.0, 0.35, 0.05, 0.10 * a2))
		for i in range(6):
			var ang := t * 2.0 + i
			var p: Vector2 = f["pos"] + Vector2(cos(ang), sin(ang)) * rad * 0.5 * (0.6 + 0.4 * sin(t * 5.0 + i))
			draw_circle(p, 10.0 + 4.0 * sin(t * 6.0 + i), Color(1.0, 0.45, 0.1, 0.20 * a2))
	# explosion rings
	for r in rings:
		var k := 1.0 - float(r["life"]) / float(r["max"])
		var rad2 := float(r["radius"]) * (0.2 + k * 0.9)
		var col: Color = r.get("color", Color(1.0, 0.6, 0.2))
		draw_arc(r["pos"], rad2, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.6 * (1.0 - k)), 4.0)
		draw_circle(r["pos"], rad2 * 0.6, Color(col.r, col.g, col.b, 0.12 * (1.0 - k)))
	# particles
	for p in particles:
		var a3 := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var c2: Color = p["color"]
		draw_circle(p["pos"], float(p["size"]) * (0.5 + a3 * 0.5), Color(c2.r, c2.g, c2.b, c2.a * a3))
	# damage numbers
	var font := ThemeDB.fallback_font
	for tx in texts:
		var a4 := clampf(float(tx["life"]) / float(tx["max"]), 0.0, 1.0)
		var c3: Color = tx["color"]
		draw_string(font, tx["pos"] - Vector2(10, 0), str(tx["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(c3.r, c3.g, c3.b, a4))


## Is a point inside a smoke cloud? Used by vision + AI.
func smoke_at(pos: Vector2) -> bool:
	for s in smoke_clouds:
		if float(s["radius"]) < 8.0:
			continue
		if (s["pos"] as Vector2).distance_to(pos) < float(s["radius"]) * 0.6:
			return true
	return false


## Does any smoke cloud intersect the segment? Used for line-of-sight fog.
func smoke_on_line(from: Vector2, to: Vector2) -> bool:
	for s in smoke_clouds:
		var rad := float(s["radius"]) * 0.75
		if rad < 10.0:
			continue
		var p: Vector2 = s["pos"]
		var ab := to - from
		var t := clampf((p - from).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
		if (from + ab * t).distance_to(p) < rad:
			return true
	return false


func fire_at(pos: Vector2) -> bool:
	for f in fires:
		if f["pos"].distance_to(pos) < float(f["radius"]):
			return true
	return false
