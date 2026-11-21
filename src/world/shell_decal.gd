class_name ShellDecal
extends Node2D
var dir := Vector2.RIGHT

func _draw() -> void:
	var c := Color(0.7843, 0.6353, 0.2902)
	draw_rect(Rect2(-2.5, -1.0, 5.0, 2.0), c, true)
	draw_rect(Rect2(-2.5, -1.0, 2.0, 2.0), Color(0.5412, 0.4235, 0.1647), true)

