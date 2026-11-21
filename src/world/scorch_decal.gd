class_name ScorchDecal
extends Node2D
var radius := 40.0

func _draw() -> void:
	for i in range(3):
		var rr := radius * (1.0 - float(i) * 0.28)
		draw_circle(Vector2.ZERO, rr, Color(0, 0, 0, 0.12), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in range(10):
		var a := rng.randf_range(0, TAU)
		draw_line(Vector2(cos(a), sin(a)) * radius * 0.4, Vector2(cos(a), sin(a)) * radius, Color(0, 0, 0, 0.25), 2.0)
