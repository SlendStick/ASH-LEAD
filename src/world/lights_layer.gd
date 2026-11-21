extends Node2D
## Dynamic neon lighting: point lights with flicker, lamp cones, police beacons,
## muzzle flashes, emergency strobes. Uses additive drawing so the whole scene
## reads as "wet asphalt under neon" without a costly 2D pipeline.

var map: GeneratedMap
var visual: Node2D
var lights: Array[Dictionary] = []
var t := 0.0
var muzzle_flashes: Array[Dictionary] = []
var beacons: Array[Dictionary] = []
var glow_root: Node2D = null


func build() -> void:
	lights.clear()
	beacons.clear()
	if map == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value + 3
	for l in map.lights:
		var col := Color(str(l.get("color", "#35c9ff")))
		var radius := float(l.get("radius", 180.0))
		var pos := map.cell_to_world(l["cell"])
		var l2 := {
			"pos": pos, "color": col, "radius": radius,
			"flicker": bool(l.get("flicker", false)),
			"power": float(l.get("power", 1.0)),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.6, 2.4),
			"kind": str(l.get("kind", "room")),
		}
		lights.append(l2)
	_spawn_glow_nodes()
	set_process(true)


## GPU halos on top of the cheap CPU pools: one NeonGlow per real light source
## (room lamps, street lamps, neon signs), skipped for tiny lights so a big map
## does not spawn hundreds of shader quads.
func _spawn_glow_nodes() -> void:
	if glow_root != null and is_instance_valid(glow_root):
		glow_root.queue_free()
	glow_root = Node2D.new()
	glow_root.name = "Glow"
	glow_root.z_index = 1
	add_child(glow_root)
	for l in lights:
		var radius := float(l["radius"])
		if radius < 90.0:
			continue
		var g := NeonGlow.new()
		g.z_index = 1
		glow_root.add_child(g)
		g.setup(l["color"], radius * 1.15, float(l["power"]))
		g.tube = 0.35 if str(l.get("kind", "")) == "street" else 0.0
		g.flicker = 0.6 if bool(l.get("flicker", false)) else 0.0


func set_alarm(level: int) -> void:
	if glow_root == null:
		return
	var p := clampf(float(level) / 2.0, 0.0, 1.0)
	for g in glow_root.get_children():
		if g is NeonGlow:
			g.set_alarm_pulse(p)


func tick(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	# light pools drawn additively
	for l in lights:
		var flick := 1.0
		if bool(l["flicker"]):
			var ph := float(l["phase"])
			flick = 0.55 + 0.45 * abs(sin(t * float(l["speed"]) + ph))
			if sin(t * 9.0 + ph) > 0.97:
				flick *= 0.25
		var power := float(l["power"]) * flick
		var col: Color = l["color"]
		var radius := float(l["radius"])
		var pos: Vector2 = l["pos"]
		# layered radial falloff (cheap volumetric approximation)
		for i in range(4, 0, -1):
			var rr := radius * float(i) / 4.0
			var a := 0.028 * power * (1.0 - float(i) / 5.0)
			draw_circle(pos, rr, Color(col.r, col.g, col.b, a))
		draw_circle(pos, 12.0, Color(col.r, col.g, col.b, 0.22 * power))
		draw_circle(pos, 5.0, Color(1, 1, 1, 0.25 * power))
		# light cone on the ground for street lamps
		if str(l.get("kind", "")) == "street":
			var dir := Vector2(0, 1).rotated(sin(float(l["phase"])) * 0.2)
			var poly := PackedVector2Array([
				pos + dir.rotated(-0.5) * 30.0,
				pos + dir.rotated(-0.28) * radius,
				pos + dir.rotated(0.28) * radius,
				pos + dir.rotated(0.5) * 30.0,
			])
			draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.03 * power))
	# temporary muzzle flashes
	var keep: Array[Dictionary] = []
	for f in muzzle_flashes:
		var life := float(f.get("life", 0.0))
		if life <= 0.0:
			continue
		var c: Color = f["color"]
		var p: Vector2 = f["pos"]
		draw_circle(p, 34.0, Color(c.r, c.g, c.b, 0.18))
		draw_circle(p, 14.0, Color(c.r, c.g, c.b, 0.4))
		draw_circle(p, 5.0, Color(1, 1, 1, 0.8))
		f["life"] = life - 0.05
		keep.append(f)
	muzzle_flashes = keep
	# police beacons
	for b in beacons:
		var life2 := float(b.get("life", 0.0))
		if life2 <= 0.0:
			continue
		var pos2: Vector2 = b["pos"]
		var pulse := (sin(t * 12.0) + 1.0) * 0.5
		var col2 := Color(0.2, 0.5, 1.0).lerp(Color(1.0, 0.15, 0.3), pulse)
		draw_circle(pos2, 90.0, Color(col2.r, col2.g, col2.b, 0.05))
		draw_circle(pos2, 40.0, Color(col2.r, col2.g, col2.b, 0.10))
		b["life"] = life2 - 0.05
		keep.append(b)
	beacons = beacons.filter(func(x): return float(x.get("life", 0.0)) > 0.0)


func flash(pos: Vector2, color: Color = Color(1.0, 0.9, 0.6), life: float = 0.12) -> void:
	muzzle_flashes.append({"pos": pos, "color": color, "life": life})


func beacon(pos: Vector2, seconds: float = 1.0) -> void:
	beacons.append({"pos": pos, "life": seconds})
