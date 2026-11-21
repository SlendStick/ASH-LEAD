class_name ActorVisual
extends Node2D
## Procedural top-down character art.
##
## Each actor is drawn from primitives in local space (facing +X): boots, coat,
## vest, arms, weapon in hand, head, gear silhouette. Outfits come from Db and
## change per mode (criminal heist suit vs SWAT vs patrol), team colours are
## readable at a glance, and animation is done with simple procedural offsets
## (walk cycle, recoil, stumble, downed pose, surrender pose).

var team := 0
var outfit_id := "heist"
var colors: Array = ["#161320", "#2a2138", "#ff2b62"]
var head_color := Color(0.051, 0.0431, 0.0784)
var visor_color := Color(1.0, 0.1686, 0.3843)
var gear: Array = []
var weapon_id := ""
var suppressed := false
var flash := 0.0
var walk_phase := 0.0
var moving := false
var downed := false
var surrendering := false
var aiming := false
var crouching := false
var carrying_bag := false
var carrying_hostage := false
var dead := false
var is_bot := false
var highlight := 0.0
var coat_sway := 0.0
var aim_angle := 0.0
var blood_stains: Array[Vector2] = []
var flash_time := 0.0


func setup(team_id: int, outfit: String) -> void:
	team = team_id
	outfit_id = outfit
	var src: Dictionary = {}
	if team_id == Db.TEAM_POLICE:
		src = Db.POLICE_OUTFITS.get(outfit, Db.POLICE_OUTFITS["patrol"])
	else:
		src = Db.CRIMINAL_OUTFITS.get(outfit, Db.CRIMINAL_OUTFITS["heist"])
	colors = src.get("colors", ["#161320", "#2a2138", "#ff2b62"])
	head_color = Color(str(src.get("head", "#0d0b14")))
	visor_color = Color(str(src.get("visor", "#ff2b62")))
	gear = src.get("gear", [])
	queue_redraw()


func set_civilian(arch: Dictionary) -> void:
	team = Db.TEAM_CIVILIAN
	colors = arch.get("colors", ["#2b2a3d", "#7b7890", "#bfefff"])
	head_color = Color(str(colors[2]))
	visor_color = Color(str(colors[1]))
	gear = ["casual"]
	queue_redraw()


func tick(delta: float) -> void:
	walk_phase += delta * (11.0 if moving else 2.0)
	coat_sway = sin(walk_phase * 0.6) * (4.0 if moving else 1.2)
	flash_time = maxf(0.0, flash_time - delta)
	highlight = maxf(0.0, highlight - delta * 2.5)
	queue_redraw()


func muzzle_flash() -> void:
	flash_time = 0.07


func add_blood_stain(local_dir: Vector2) -> void:
	blood_stains.append(local_dir.normalized() * 8.0)
	if blood_stains.size() > 8:
		blood_stains.pop_front()


func _draw() -> void:
	var base: Color = Color(str(colors[0]))
	var accent: Color = Color(str(colors[2]))
	var mid: Color = Color(str(colors[1]))
	var walking := moving and not downed and not dead
	var bob := sin(walk_phase) * 2.4 if walking else 0.0
	var body_scale := 0.94 if crouching else 1.0

	var shadow := Color(0, 0, 0, 0.45)
	if dead:
		_draw_corpse(base, accent)
		return
	if downed:
		_draw_downed(base, accent, mid)
		return

	# shadow ellipse
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.25, 1.0))
	draw_circle(Vector2.ZERO, 15.0, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# bag / hostage on the back
	if carrying_bag:
		draw_rect(Rect2(-22, -10, 14, 20), Color(0.1686, 0.1294, 0.0745), true)
		draw_rect(Rect2(-22, -10, 14, 20), Color(0.3529, 0.2706, 0.1255), false, 1.5)
		draw_circle(Vector2(-15, 0), 4.0, Color(1.0, 0.75, 0.2, 0.6), true)

	# legs
	var leg_off := sin(walk_phase) * 5.0 if walking else 0.0
	var leg_col := base.darkened(0.25)
	draw_line(Vector2(-6, -9 * body_scale), Vector2(-6 + leg_off, -16 * body_scale), leg_col, 6.0)
	draw_line(Vector2(-6, 9 * body_scale), Vector2(-6 - leg_off, 16 * body_scale), leg_col, 6.0)
	# boots
	draw_circle(Vector2(-6 + leg_off, -17 * body_scale), 4.0, Color(0.0392, 0.0392, 0.0588))
	draw_circle(Vector2(-6 - leg_off, 17 * body_scale), 4.0, Color(0.0392, 0.0392, 0.0588))

	# coat / torso
	var torso := PackedVector2Array([
		Vector2(-13, -12 * body_scale), Vector2(9, -13 * body_scale),
		Vector2(13, -6), Vector2(13, 6), Vector2(9, 13 * body_scale),
		Vector2(-13, 12 * body_scale), Vector2(-16 + coat_sway * 0.2, 0),
	])
	draw_colored_polygon(torso, base)
	draw_polyline(torso, base.lightened(0.16), 1.5)
	# coat tail sway
	if outfit_id in ["heist", "detective", "hostage"] or "coat" in str(gear):
		var tail := PackedVector2Array([
			Vector2(-13, -11 * body_scale), Vector2(-22 + coat_sway, -8),
			Vector2(-24 + coat_sway, 8), Vector2(-13, 11 * body_scale),
		])
		draw_colored_polygon(tail, base.darkened(0.12))

	# armour plate / vest
	if "plate_carrier" in gear or "chest_rig" in gear or "kevlar_vest" in gear or "covert_vest" in gear:
		draw_rect(Rect2(-4, -10 * body_scale, 13, 20 * body_scale), mid.darkened(0.25), true)
		draw_rect(Rect2(-4, -10 * body_scale, 13, 20 * body_scale), mid, false, 1.2)
		draw_rect(Rect2(2, -6, 5, 4), accent.darkened(0.2), true)
	# hi-vis stripes for patrol
	if "hi_vis_stripes" in gear:
		draw_line(Vector2(-6, -11), Vector2(-6, 11), mid, 2.5)
		draw_line(Vector2(1, -11), Vector2(1, 11), mid, 1.5)

	# arms + weapon
	_draw_arms(base, accent)

	# head
	var head_pos := Vector2(7, bob * 0.4)
	if crouching:
		head_pos.y += 1.0
	draw_circle(head_pos, 8.5, head_color)
	draw_circle(head_pos, 8.5, head_color.lightened(0.18), false, 1.2)
	# mask / visor
	if team == Db.TEAM_CRIMINAL:
		if "balaclava" in gear:
			draw_circle(head_pos, 8.2, head_color, true)
			draw_rect(Rect2(head_pos + Vector2(2, -4), Vector2(6, 3)), visor_color, true)
			draw_rect(Rect2(head_pos + Vector2(2, 1), Vector2(6, 3)), visor_color, true)
		elif "president_mask" in gear:
			draw_circle(head_pos, 8.0, Color(0.9098, 0.8902, 0.8353), true)
			draw_circle(head_pos + Vector2(3, -2.5), 1.6, Color(0.0392, 0.0392, 0.0588), true)
			draw_circle(head_pos + Vector2(3, 2.5), 1.6, Color(0.0392, 0.0392, 0.0588), true)
			draw_arc(head_pos + Vector2(2, 0), 4.0, -0.6, 0.6, 6, Color(0.4784, 0.0, 0.0863), 1.5)
		elif "skull_mask" in gear:
			draw_circle(head_pos, 8.0, Color(0.9098, 0.8902, 0.8353), true)
			draw_circle(head_pos + Vector2(3, -2.5), 2.0, Color(0.0392, 0.0392, 0.0588), true)
			draw_circle(head_pos + Vector2(3, 2.5), 2.0, Color(0.0392, 0.0392, 0.0588), true)
			draw_line(head_pos + Vector2(1, 5), head_pos + Vector2(6, 5), Color(0.0392, 0.0392, 0.0588), 1.4)
		elif "rabbit_mask" in gear:
			draw_circle(head_pos, 8.4, Color(0.1686, 0.1059, 0.2392), true)
			draw_line(head_pos + Vector2(-2, -6), head_pos + Vector2(-6, -18), Color(0.1686, 0.1059, 0.2392), 4.0)
			draw_line(head_pos + Vector2(2, -6), head_pos + Vector2(6, -18), Color(0.1686, 0.1059, 0.2392), 4.0)
			draw_circle(head_pos + Vector2(4, 0), 2.0, visor_color, true)
		elif "welded_helmet" in gear:
			draw_circle(head_pos, 9.0, Color(0.2275, 0.2471, 0.2784), true)
			for i in range(3):
				draw_line(head_pos + Vector2(4, -5 + i * 4), head_pos + Vector2(8, -5 + i * 4), Color(0.0392, 0.0392, 0.0588), 1.5)
		else:
			draw_circle(head_pos + Vector2(2, -3), 1.7, Color(0.0392, 0.0392, 0.0588), true)
			draw_circle(head_pos + Vector2(2, 3), 1.7, Color(0.0392, 0.0392, 0.0588), true)
	else:
		# police: helmet, visor, cap, fedora
		if "helmet" in gear or "riot_helmet" in gear or "blast_visor" in gear:
			draw_circle(head_pos, 9.5, Color(0.102, 0.1216, 0.1569), true)
			draw_rect(Rect2(head_pos + Vector2(4, -5), Vector2(5, 10)), visor_color, true)
		elif "fedora" in gear:
			draw_circle(head_pos, 10.5, base.darkened(0.35), true)
			draw_circle(head_pos, 8.5, base, true)
		elif "patrol_cap" in gear:
			draw_arc(head_pos, 8.8, PI * 0.8, PI * 1.9, 10, base.darkened(0.3), 4.0)
			draw_rect(Rect2(head_pos + Vector2(3, -5), Vector2(7, 10)), visor_color, true)
		elif "buff_mask" in gear:
			draw_circle(head_pos, 8.4, visor_color.darkened(0.45), true)
		else:
			draw_circle(head_pos + Vector2(2, -3), 1.7, Color(0.9, 0.9, 0.95), true)
			draw_circle(head_pos + Vector2(2, 3), 1.7, Color(0.9, 0.9, 0.95), true)

	# flashlight cone hint
	if "flashlight_mount" in gear or "flashlight" in gear:
		var cone := PackedVector2Array([Vector2(12, -3), Vector2(64, -22), Vector2(64, 22), Vector2(12, 3)])
		draw_colored_polygon(cone, Color(1, 0.95, 0.8, 0.05))

	# blood on the coat
	for b in blood_stains:
		draw_circle(b, 2.6, Color(0.42, 0.0, 0.05, 0.8))

	# surrender pose
	if surrendering:
		draw_line(Vector2(2, -10), Vector2(14, -20), base.lightened(0.1), 5.0)
		draw_line(Vector2(2, 10), Vector2(14, 20), base.lightened(0.1), 5.0)

	# highlight ring when pinged / spotted
	if highlight > 0.0:
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 20, Color(1, 1, 1, 0.35 * highlight), 2.0)
	if is_bot:
		draw_circle(Vector2(0, -26), 2.2, Color(0.6, 0.65, 0.8, 0.5), true)


func _draw_arms(base: Color, accent: Color) -> void:
	var w: Dictionary = Db.WEAPONS.get(weapon_id, {})
	var kind := str(w.get("kind", "pistol"))
	var hands := Vector2(16, 0)
	var recoil_back := -2.0 if flash_time > 0.0 else 0.0
	if aiming:
		hands.x += 2.0
	if kind == "melee":
		var blade_len := 22.0
		draw_line(Vector2(6, 2), Vector2(6 + blade_len * 0.5, 4), base.lightened(0.1), 5.0)
		draw_line(Vector2(6 + blade_len * 0.5, 4), Vector2(6 + blade_len, 2), Color(0.7882, 0.8235, 0.8549), 3.0)
		draw_line(Vector2(6 + blade_len, 2), Vector2(6 + blade_len + 4, 0), Color(0.9333, 0.9569, 0.9804), 1.5)
		return
	if kind == "throw":
		draw_circle(Vector2(14, 3), 4.5, Color(0.1686, 0.2275, 0.1451), true)
		draw_circle(Vector2(14, 3), 4.5, accent, false, 1.0)
		return
	# arm
	draw_line(Vector2(2, -6), hands + Vector2(-4, -3) + Vector2(recoil_back, 0), base.lightened(0.14), 5.0)
	draw_line(Vector2(2, 6), hands + Vector2(-2, 2) + Vector2(recoil_back, 0), base.lightened(0.05), 5.0)
	# weapon body
	var len := 18.0
	var thick := 4.0
	match kind:
		"rifle", "lmg":
			len = 34.0
			thick = 4.6
		"smg":
			len = 24.0
			thick = 4.2
		"shotgun":
			len = 32.0
			thick = 5.2
		"sniper":
			len = 40.0
			thick = 4.0
		"special":
			len = 30.0
			thick = 6.5
		"pistol":
			len = 15.0
			thick = 3.6
	var gun_col := Color(0.0784, 0.0863, 0.1098)
	var start := hands + Vector2(recoil_back, 0)
	draw_line(start, start + Vector2(len, 0), gun_col, thick)
	draw_line(start, start + Vector2(len * 0.55, 0), gun_col.lightened(0.25), thick * 0.4)
	# magazine
	draw_rect(Rect2(start + Vector2(len * 0.35, 2), Vector2(4, 6)), Color(0.051, 0.0549, 0.0706), true)
	# scope
	if kind == "sniper" or weapon_id == "svd":
		draw_rect(Rect2(start + Vector2(len * 0.3, -4), Vector2(10, 3)), Color(0.0392, 0.0471, 0.0627), true)
	# suppressor
	if suppressed:
		draw_rect(Rect2(start + Vector2(len, -thick * 0.45), Vector2(10, thick * 0.9)), Color(0.0627, 0.0706, 0.0941), true)
	# hands
	draw_circle(start + Vector2(len * 0.22, 2), 3.2, base.darkened(0.1), true)
	draw_circle(start + Vector2(len * 0.55, 0), 2.6, base.darkened(0.1), true)
	# muzzle flash
	if flash_time > 0.0:
		var tip := start + Vector2(len + (10.0 if suppressed else 0.0), 0)
		draw_circle(tip, 9.0, Color(1.0, 0.85, 0.4, 0.55), true)
		draw_circle(tip, 5.0, Color(1.0, 0.97, 0.8, 0.9), true)
		var spike := PackedVector2Array([tip + Vector2(-2, -7), tip + Vector2(16, 0), tip + Vector2(-2, 7)])
		draw_colored_polygon(spike, Color(1.0, 0.8, 0.35, 0.5))


func _draw_downed(base: Color, accent: Color, mid: Color) -> void:
	draw_set_transform(Vector2(0, 0), 0.6, Vector2(1.0, 0.7))
	draw_circle(Vector2(0, 0), 16.0, base.darkened(0.15))
	draw_circle(Vector2(9, 0), 8.0, head_color)
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.2), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# crawl marker
	draw_circle(Vector2(0, -20), 2.0, Color(1, 0.2, 0.3, 0.6))
	draw_circle(Vector2(0, -26), 1.5, Color(1, 0.2, 0.3, 0.35))


func _draw_corpse(base: Color, accent: Color) -> void:
	draw_set_transform(Vector2(0, 0), 0.35, Vector2(1.1, 0.85))
	draw_circle(Vector2.ZERO, 15.0, base.darkened(0.3))
	var torso := PackedVector2Array([
		Vector2(-14, -8), Vector2(6, -10), Vector2(12, -3), Vector2(12, 4), Vector2(6, 9), Vector2(-14, 8),
	])
	draw_colored_polygon(torso, base.darkened(0.2))
	draw_circle(Vector2(11, 0), 7.5, head_color.darkened(0.2))
	# limp limb
	draw_line(Vector2(-8, 4), Vector2(-20, 14), base.darkened(0.35), 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-16, 12), 6.0, Color(0.32, 0.0, 0.05, 0.35))
