class_name Crosshair
extends Control
## Dynamic crosshair: spread follows weapon accuracy, recoil bloom on fire,
## hitmarker X, headshot flash, damage direction wedges, and a "downed/aim"
## variant. Drawn every frame; no textures.

var world: Node
var spread := 10.0
var hit_timer := 0.0
var hit_head := false
var kill_timer := 0.0
var show := true
var damage_dirs: Array[Dictionary] = []
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Signals.hit_confirmed.connect(_on_hit)
	Signals.damage_number.connect(_on_damage)


func _on_hit(is_kill: bool, headshot: bool, _team: int) -> void:
	hit_timer = 0.22
	hit_head = headshot
	if is_kill:
		kill_timer = 0.4


func _on_damage(_pos: Vector2, _amount: float, kind: String) -> void:
	if kind.begins_with("dir:"):
		add_damage_dir(float(kind.substr(4)))


func add_damage_dir(angle: float) -> void:
	damage_dirs.append({"angle": angle, "life": 0.8, "max": 0.8})


func _process(delta: float) -> void:
	t += delta
	hit_timer = maxf(0.0, hit_timer - delta)
	kill_timer = maxf(0.0, kill_timer - delta)
	var keep: Array[Dictionary] = []
	for d in damage_dirs:
		d["life"] = float(d["life"]) - delta
		if float(d["life"]) > 0.0:
			keep.append(d)
	damage_dirs = keep
	queue_redraw()


func _draw() -> void:
	var center := get_local_mouse_position()
	var accent := Color(0.55, 1.0, 0.72, 0.95)
	if world != null and world.get("local_actor") != null:
		var a = world.get("local_actor")
		if a.dead:
			return
		if a.flash_timer > 0.0:
			accent = Color(1, 1, 1, 0.4)
	# damage direction wedges drawn as short arcs around the crosshair
	for d in damage_dirs:
		var k := float(d["life"]) / float(d["max"])
		var ang: float = d["angle"]
		var c := Color(1.0, 0.2, 0.3, 0.65 * k)
		var pts := PackedVector2Array()
		for i in range(5):
			var a := ang - 0.24 + 0.12 * float(i)
			pts.append(center + Vector2(cos(a), sin(a)) * 62.0)
		for i in range(5):
			var a2 := ang + 0.24 - 0.12 * float(i)
			pts.append(center + Vector2(cos(a2), sin(a2)) * 46.0)
		draw_colored_polygon(pts, c)
	if not show:
		return
	var gap := 4.0 + spread * 2.2
	var arm := 7.0
	var col := accent
	var thickness := 2.0
	# 4 lines
	draw_line(center + Vector2(-gap - arm, 0), center + Vector2(-gap, 0), col, thickness)
	draw_line(center + Vector2(gap, 0), center + Vector2(gap + arm, 0), col, thickness)
	draw_line(center + Vector2(0, -gap - arm), center + Vector2(0, -gap), col, thickness)
	draw_line(center + Vector2(0, gap), center + Vector2(0, gap + arm), col, thickness)
	draw_circle(center, 1.2, col)
	# hitmarker
	if hit_timer > 0.0:
		var hc := Color(1.0, 0.3, 0.35, hit_timer / 0.22) if hit_head else Color(1, 1, 1, hit_timer / 0.22)
		var k2 := 10.0 + (1.0 - hit_timer / 0.22) * 8.0
		draw_line(center + Vector2(-k2, -k2), center + Vector2(-4, -4), hc, 2.0)
		draw_line(center + Vector2(k2, -k2), center + Vector2(4, -4), hc, 2.0)
		draw_line(center + Vector2(-k2, k2), center + Vector2(-4, 4), hc, 2.0)
		draw_line(center + Vector2(k2, k2), center + Vector2(4, 4), hc, 2.0)
	if kill_timer > 0.0:
		var kk := kill_timer / 0.4
		draw_arc(center, 22.0 + (1.0 - kk) * 16.0, 0, TAU, 24, Color(1.0, 0.2, 0.3, kk), 2.5)
