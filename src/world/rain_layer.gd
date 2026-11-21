extends Node2D
## Rain and dust: diagonal streaks that slide against the camera, splash rings
## on puddles, embers in burning rooms. Sits above actors for depth.

var map: GeneratedMap
var drops: Array[Dictionary] = []
var splashes: Array[Dictionary] = []
var t := 0.0
var intensity := 1.0
var wind := Vector2(-0.35, 1.0)


func build() -> void:
	drops.clear()
	if map == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value + 21
	for i in range(220):
		drops.append({
			"pos": Vector2(rng.randf_range(0, map.w * GeneratedMap.TILE), rng.randf_range(0, map.h * GeneratedMap.TILE)),
			"len": rng.randf_range(10, 26),
			"speed": rng.randf_range(700, 1300),
			"alpha": rng.randf_range(0.08, 0.35),
		})
	set_process(true)


func tick(delta: float) -> void:
	t += delta
	if map == null:
		return
	var view := get_viewport_rect()
	var cam_center := Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam_center = cam.global_position
	var area := Rect2(cam_center - view.size * 0.75, view.size * 1.5)
	for d in drops:
		var p: Vector2 = d["pos"]
		p += wind.normalized() * float(d["speed"]) * delta * intensity
		if p.y > area.end.y:
			p = Vector2(area.position.x + fmod(abs(p.x), area.size.x), area.position.y - 20.0)
		if p.x < area.position.x - 100 or p.x > area.end.x + 100:
			p.x = area.position.x + fmod(abs(p.x), area.size.x)
		d["pos"] = p
	# splash rings spawn near camera on the ground
	if randf() < 0.55 * intensity:
		var sp := Vector2(cam_center.x + randf_range(-view.size.x * 0.6, view.size.x * 0.6), cam_center.y + randf_range(-view.size.y * 0.6, view.size.y * 0.6))
		splashes.append({"pos": map.cell_to_world(map.world_to_cell(sp)) + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "life": 0.45, "max": 0.45})
	var keep: Array[Dictionary] = []
	for s in splashes:
		var life := float(s["life"]) - delta
		if life > 0.0:
			s["life"] = life
			keep.append(s)
	splashes = keep
	queue_redraw()


func _draw() -> void:
	for d in drops:
		var p: Vector2 = d["pos"]
		var dir := wind.normalized()
		draw_line(p, p - dir * float(d["len"]), Color(0.7, 0.85, 1.0, float(d["alpha"])), 1.0)
	for s in splashes:
		var k := 1.0 - float(s["life"]) / float(s["max"])
		var r := 4.0 + k * 12.0
		draw_arc(s["pos"], r, 0, TAU, 12, Color(0.7, 0.9, 1.0, 0.18 * (1.0 - k)), 1.5)
