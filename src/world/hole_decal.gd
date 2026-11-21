class_name HoleDecal
extends Node2D

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.65), true)
	draw_circle(Vector2.ZERO, 1.2, Color(0.3, 0.3, 0.35, 0.5), true)
	draw_line(Vector2(0, 0), Vector2(6, 2), Color(0, 0, 0, 0.3), 1.0)

