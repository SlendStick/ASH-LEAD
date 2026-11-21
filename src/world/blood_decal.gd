class_name BloodDecal
extends Node2D
## Pool + splatter. Drawn once, then kept forever in the map decal layer.

var amount := 1.0
var dir := Vector2.RIGHT
var _drawn := false


func _ready() -> void:
	queue_redraw()
	z_as_relative = true


func _draw() -> void:
	if _drawn:
		return
	_drawn = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(position.x * 31.0 + position.y * 17.0))
	var dark := Color(0.32, 0.0, 0.05, 0.75)
	var bright := Color(0.62, 0.02, 0.10, 0.65)
	var radius := 16.0 + amount * 12.0
	# main pool with an irregular edge
	var pts := PackedVector2Array()
	var segs := 14
	for i in range(segs):
		var a := TAU * float(i) / float(segs)
		var rr := radius * (0.65 + rng.randf() * 0.5)
		pts.append(Vector2(cos(a), sin(a)) * rr + dir * radius * 0.25)
	draw_colored_polygon(pts, dark)
	# splatter in the direction of the wound
	var count := int(6 + amount * 8)
	for i in range(count):
		var ang := dir.angle() + rng.randf_range(-0.9, 0.9)
		var dist := rng.randf_range(radius * 0.6, radius * (1.4 + amount * 0.9))
		var p := Vector2(cos(ang), sin(ang)) * dist
		var size := rng.randf_range(1.5, 5.5)
		draw_circle(p, size, bright if rng.randf() < 0.5 else dark)
	# arterial streak
	if amount > 0.7:
		var tail := PackedVector2Array()
		for i in range(5):
			tail.append(dir * (radius * 0.4 + i * radius * 0.45) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)))
		draw_polyline(tail, Color(0.5, 0.0, 0.08, 0.5), 5.0)

