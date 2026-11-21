class_name FogPainter
extends Node2D
## Atmospheric haze: dark fog banks hugging the corners of rooms, drifting mist
## on the street and low-lying smoke over puddles. Purely visual; vision itself
## is computed by VisionSystem.

const T := GeneratedMap.TILE

var map: GeneratedMap
var t := 0.0
var hud_mode := false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	t += delta
	if not hud_mode:
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var fog_col := Color(str(map.theme.get("fog", ["#121024"])[0]))
	var fog_col2 := Color(str(map.theme.get("fog", ["#121024", "#1b1533"])[1]))
	var rng := RandomNumberGenerator.new()
	# corner fog inside rooms, very low alpha
	for i in range(map.rooms.size()):
		var r: Rect2i = map.rooms[i]["rect"]
		var points := [
			Vector2(r.position) * T,
			Vector2(r.position.x + r.size.x, r.position.y) * T,
			Vector2(r.position) * T + Vector2(0, r.size.y * T),
			Vector2(r.position + r.size) * T,
		]
		for k in range(points.size()):
			var wob := sin(t * 0.6 + i + k) * 10.0
			var c: Vector2 = points[k] + Vector2(wob, wob * 0.5)
			draw_circle(c, 80.0, Color(fog_col.r, fog_col.g, fog_col.b, 0.22))
			draw_circle(c, 46.0, Color(fog_col2.r, fog_col2.g, fog_col2.b, 0.18))
	# street mist
	rng.seed = 4
	for i in range(40):
		var p := Vector2(rng.randf_range(0, map.w * T), rng.randf_range(0, map.h * T))
		var drift := sin(t * 0.3 + i) * 22.0
		draw_circle(p + Vector2(drift, drift * 0.4), rng.randf_range(50, 120), Color(fog_col2.r, fog_col2.g, fog_col2.b, 0.07))
