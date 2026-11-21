class_name Minimap
extends Control
## Tactical minimap with fog of war: explored geometry, teammates, detected
## enemies, objectives, evacuation zones and pings.

var match_ref: Match
var big: bool = false
var _timer := 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.12:
		_timer = 0.0
		queue_redraw()


func _draw() -> void:
	if match_ref == null or match_ref.map_data == null:
		return
	var map_data: MapData = match_ref.map_data
	var team := match_ref.local_team
	var size := size_if_needed()
	var scale := Vector2(size.x / map_data.width, size.y / map_data.height)
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.045, 0.85))
	var explored: Dictionary = match_ref.fog.explored.get(team, {})
	var visible: Dictionary = match_ref.fog.visible.get(team, {})
	for tile in explored.keys():
		var t: Vector2i = tile
		var col := Color(0.12, 0.16, 0.2, 0.55)
		if visible.has(t):
			col = Color(0.2, 0.27, 0.32, 0.85)
		draw_rect(Rect2(Vector2(t.x, t.y) * scale, scale * 0.92), col)
	# Walls on explored tiles
	for tile in explored.keys():
		var t: Vector2i = tile
		if map_data.blocks_sight(t.x, t.y):
			draw_rect(Rect2(Vector2(t.x, t.y) * scale, scale * 0.92), Color(0.35, 0.42, 0.5, 0.6))
	# Evac zones
	for e in map_data.evac:
		var p: Vector2 = e["pos"] / MapData.TILE_SIZE
		draw_circle(Vector2(p.x, p.y) * scale, 4.0, Color(0.3, 0.85, 0.7, 0.8))
	# Objectives
	for o in map_data.objectives:
		var p: Vector2 = o["pos"] / MapData.TILE_SIZE
		draw_circle(Vector2(p.x, p.y) * scale, 5.0, Color(0.95, 0.75, 0.25, 0.95))
	# Teammates
	for c in match_ref.characters:
		if c.team != team or not c.alive or c.team == GameTypes.Team.CIVILIAN:
			continue
		var p: Vector2 = c.global_position / MapData.TILE_SIZE
		var marker_color := Color(0.3, 0.85, 0.6)
		if c == match_ref.local_player:
			marker_color = Color(0.4, 0.95, 1.0)
		draw_circle(Vector2(p.x, p.y) * scale, 3.4, marker_color)
	# Detected enemies (only genuinely seen)
	var detected: Dictionary = match_ref.fog.get_detected(team)
	for enemy in detected:
		var entry: Dictionary = detected[enemy]
		var p: Vector2 = entry.get("pos", Vector2.ZERO) / MapData.TILE_SIZE
		var col := Color(0.95, 0.3, 0.3, 0.95)
		if bool(entry.get("uncertain", false)):
			col = Color(0.9, 0.6, 0.2, 0.6)
		draw_circle(Vector2(p.x, p.y) * scale, 3.2, col)


func size_if_needed() -> Vector2:
	var s := size
	if s.x <= 1.0:
		s = Vector2(252, 204)
	return s
