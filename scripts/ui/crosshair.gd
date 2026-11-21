class_name Crosshair
extends Control
## Small neon crosshair drawn at the mouse position (system cursor is hidden).

var spread: float = 10.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var mouse := get_local_mouse_position()
	var color := Color(0.25, 0.95, 0.85, 0.9)
	var gap := 5.0 + spread
	var length := 7.0
	draw_line(mouse + Vector2(gap, 0), mouse + Vector2(gap + length, 0), color, 2.0)
	draw_line(mouse + Vector2(-gap, 0), mouse + Vector2(-gap - length, 0), color, 2.0)
	draw_line(mouse + Vector2(0, gap), mouse + Vector2(0, gap + length), color, 2.0)
	draw_line(mouse + Vector2(0, -gap), mouse + Vector2(0, -gap - length), color, 2.0)
	draw_circle(mouse, 1.6, color)
