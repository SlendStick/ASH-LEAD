class_name Minimap
extends Control
## Tactical minimap with fog of war: only geometry the team has seen is drawn,
## live enemies show while an ally has line of sight, last-known contacts blink
## red, objectives and the squad show always. Player ping marks points.

var world: Node
var map: GeneratedMap
var explored: Dictionary = {}
var ping_marks: Array[Dictionary] = []
var t := 0.0
var zoom := 3.0
var mode := "map"  # map | radar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Signals.ui_ping.connect(_on_ping)


func _on_ping(pos: Vector2, kind: String) -> void:
	ping_marks.append({"pos": pos, "kind": kind, "life": 4.0, "max": 4.0})


func _process(delta: float) -> void:
	t += delta
	var keep: Array[Dictionary] = []
	for p in ping_marks:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) > 0.0:
			keep.append(p)
	ping_marks = keep
	queue_redraw()


func _draw() -> void:
	if world == null or map == null:
		return
	var player = world.get("local_actor")
	if player == null:
		return
	var cam_pl := player.global_position
	var radius_cells := 26.0
	var cell_px := size.x / (radius_cells * 2.0)
	var origin := cam_pl - Vector2(radius_cells, radius_cells) * GeneratedMap.TILE
	var team: int = player.team
	# explored memory update around the player
	var pc := map.world_to_cell(cam_pl)
	for dx in range(-14, 15):
		for dy in range(-14, 15):
			var c := pc + Vector2i(dx, dy)
			if not map.in_bounds(c):
				continue
			if Vector2(dx, dy).length() > 14.0:
				continue
			explored[c] = true
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.04, 0.72), true)
	# geometry
	for cell in explored.keys():
		var c: Vector2i = cell
		var t2 := map.tile_at(c)
		if t2 == GeneratedMap.TK_FLOOR or t2 == GeneratedMap.TK_STREET or t2 == GeneratedMap.TK_WATER:
			var rel := (Vector2(c) * GeneratedMap.TILE - origin) / GeneratedMap.TILE * cell_px
			if rel.x < -cell_px or rel.y < -cell_px or rel.x > size.x or rel.y > size.y:
				continue
			var col := Color(0.10, 0.12, 0.18, 0.9) if t2 != GeneratedMap.TK_STREET else Color(0.07, 0.08, 0.12, 0.9)
			draw_rect(Rect2(rel, Vector2(cell_px, cell_px)), col, true)
		elif t2 == GeneratedMap.TK_DOOR:
			var rel2 := (Vector2(c) * GeneratedMap.TILE - origin) / GeneratedMap.TILE * cell_px
			draw_rect(Rect2(rel2, Vector2(cell_px, cell_px)), Color(0.4, 0.3, 0.15, 0.7), true)
	# objectives
	var mode_node = world.get("mode")
	if mode_node != null:
		for o in mode_node.get("objectives"):
			if not is_instance_valid(o) or not o.active:
				continue
			var rp := (o.global_position - origin) / GeneratedMap.TILE * cell_px
			var col2 := o.color
			var blink := 0.6 + 0.4 * sin(t * 3.0 + o.global_position.x)
			draw_circle(rp, 5.0, Color(col2.r, col2.g, col2.b, blink))
			draw_circle(rp, 8.0, Color(col2.r, col2.g, col2.b, 0.25 * blink), false, 1.0)
	# actors from the per-physics snapshot (cheap)
	var vis: Dictionary = world.get("visible_enemies")
	var snap: Array = world.get("minimap_snapshot")
	for a in snap:
		var ap: Vector2 = a["p"]
		var rp2 := (ap - origin) / GeneratedMap.TILE * cell_px
		if int(a["t"]) == team:
			if bool(a["civ"]):
				draw_circle(rp2, 2.2, Color(0.75, 0.72, 0.55, 0.8))
				continue
			var col3 := Db.TEAM_COLORS.get(team, Color.WHITE)
			draw_circle(rp2, 3.4, col3)
			draw_circle(rp2, 3.4, Color.WHITE, false, 0.8)
			var f: float = a["f"]
			draw_line(rp2, rp2 + Vector2(cos(f), sin(f)) * 7.0, Color(1, 1, 1, 0.7), 1.0)
		elif vis.has(int(a["id"])):
			draw_circle(rp2, 3.2, Color(1.0, 0.2, 0.3, 0.95))
			draw_arc(rp2, 7.0, 0, TAU, 12, Color(1.0, 0.2, 0.3, 0.35), 1.0)
	# corpse markers for team
	for c2 in world.get("minimap_corpses"):
		if int(c2["t"]) != team:
			continue
		var rp4: Vector2 = (c2["p"] as Vector2 - origin) / GeneratedMap.TILE * cell_px
		draw_line(rp4 + Vector2(-3, -3), rp4 + Vector2(3, 3), Color(0.5, 0.5, 0.55, 0.8), 1.5)
		draw_line(rp4 + Vector2(3, -3), rp4 + Vector2(-3, 3), Color(0.5, 0.5, 0.55, 0.8), 1.5)
	# pings
	for p in ping_marks:
		var rp5: Vector2 = (p["pos"] - origin) / GeneratedMap.TILE * cell_px
		var k := float(p["life"]) / float(p["max"])
		draw_arc(rp5, 10.0 * (1.0 - k) + 4.0, 0, TAU, 16, Color(0.3, 1.0, 0.9, k), 2.0)
	# view cone for the local player
	var pr := (cam_pl - origin) / GeneratedMap.TILE * cell_px
	var facing: float = player.facing
	var cone := PackedVector2Array([pr])
	for i in range(9):
		var ang := facing - 0.6 + i * (1.2 / 8.0)
		cone.append(pr + Vector2(cos(ang), sin(ang)) * 26.0)
	draw_colored_polygon(cone, Color(0.3, 0.9, 1.0, 0.07))
	# border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.6, 0.9, 0.25), false, 1.0)
