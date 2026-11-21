class_name ExplosiveProp
extends Node2D
## Cars, barrels, gas canisters, fuse boxes: secondary explosions that turn the
## level into a chain reaction. Hatred-grade environmental storytelling.

var hp := 60.0
var radius := 170.0
var damage := 90.0
var kind := "car"
var exploded := false
var world: Node
var map_visual: MapVisual
var trigger_team := -1
var chain_timer := 0.0


func setup(k: String, pos: Vector2, w: Node, vis: MapVisual) -> void:
	kind = k
	global_position = pos
	world = w
	map_visual = vis
	match k:
		"barrel":
			hp = 25.0
			radius = 130.0
			damage = 110.0
		"car":
			hp = 90.0
			radius = 190.0
			damage = 130.0
		"gas":
			hp = 20.0
			radius = 150.0
			damage = 120.0
		"fuse_box":
			hp = 15.0
			radius = 90.0
			damage = 40.0
	z_index = 2


func _draw() -> void:
	if exploded:
		draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.4))
		return
	match kind:
		"barrel":
			draw_circle(Vector2.ZERO, 13.0, Color(0.2275, 0.102, 0.0706))
			draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.2902, 0.1216), false, 2.0)
			draw_circle(Vector2.ZERO, 4.0, Color(0.0392, 0.0235, 0.0196))
		"gas":
			draw_rect(Rect2(-8, -14, 16, 28), Color(0.1216, 0.2275, 0.1686), true)
			draw_rect(Rect2(-8, -14, 16, 28), Color(0.7137, 1.0, 0.1686), false, 1.5)
		"fuse_box":
			draw_rect(Rect2(-7, -10, 14, 20), Color(0.1686, 0.1647, 0.2), true)
			draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.3, 0.2, 0.9))
		"car":
			draw_rect(Rect2(-40, -20, 80, 40), Color(0.0824, 0.102, 0.149), true)
			draw_rect(Rect2(-14, -14, 30, 28), Color(0.25, 0.4, 0.55, 0.4), true)


func take_damage(amount: float, by: Actor = null) -> void:
	if exploded:
		return
	hp -= amount
	if by != null:
		trigger_team = by.team
	if hp <= 0.0:
		explode()


func explode() -> void:
	if exploded:
		return
	exploded = true
	if world != null and world.has_method("explode"):
		world.call("explode", global_position, radius, damage, null, kind)
	queue_redraw()
