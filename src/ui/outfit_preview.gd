class_name OutfitPreview
extends Control
## Small live character preview for the outfit picker: draws the same ActorVisual
## used in-game so what you pick is what you see.

var team := "crim"
var outfit_id := "heist"
var data: Dictionary = {}
var span := 0.0
var t := 0.0


func setup(team_key: String, id: String, d: Dictionary) -> void:
	team = team_key
	outfit_id = id
	data = d


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vis := ActorVisual.new()
	vis.setup(Db.TEAM_POLICE if team == "police" else Db.TEAM_CRIMINAL, outfit_id)
	vis.set("gear", data.get("gear", []))
	vis.weapon_id = "ak12" if team == "crim" else "m4"
	vis.position = Vector2(60, 42)
	vis.scale = Vector2(1.35, 1.35)
	vis.name = "Visual"
	add_child(vis)
	set_process(true)


func _process(delta: float) -> void:
	t += delta
	var vis := get_node_or_null("Visual")
	if vis != null:
		vis.position = Vector2(60, 40 + sin(t * 2.0) * 2.0)
		vis.rotation = sin(t * 0.8) * 0.08
		vis.moving = true
		vis.call("tick", delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.035, 0.6), true)
	for i in range(0, int(size.x), 12):
		draw_line(Vector2(i, 0), Vector2(i, size.y), Color(0.15, 0.1, 0.22, 0.25), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.25, 0.5, 0.25), false, 1.0)
