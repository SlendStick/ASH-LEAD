class_name DecorPainter
extends Node2D
## Top-down silhouettes for all props: furniture, cars, gurneys, shelves,
## neon signs, AC units, bodies of water and the little stories in between.

const T := GeneratedMap.TILE

var map: GeneratedMap


func _ready() -> void:
	if map != null:
		queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value + 7
	for prop in map.props:
		var c: Vector2i = prop["cell"]
		var p := Vector2(c) * T + Vector2(T, T) * 0.5
		var kind := str(prop["kind"])
		var rot := float(prop.get("rot", 0.0))
		var sc := float(prop.get("scale", 1.0))
		_draw_prop(p, kind, rot, sc, prop, rng)


func _draw_prop(p: Vector2, kind: String, rot: float, sc: float, prop: Dictionary, rng: RandomNumberGenerator) -> void:
	match kind:
		"car":
			_car(p, rot, sc)
		"dumpster":
			draw_rect(Rect2(p - Vector2(26, 18), Vector2(52, 36)), Color(0.1137, 0.1647, 0.1333), true)
			draw_rect(Rect2(p - Vector2(26, 18), Vector2(52, 36)), Color(0.1686, 0.2392, 0.1922), false, 2.0)
			draw_rect(Rect2(p - Vector2(20, 12), Vector2(40, 10)), Color(0.0471, 0.0706, 0.0588), true)
		"cone":
			draw_circle(p, 7.0, Color(1.0, 0.4784, 0.1216), true)
			draw_circle(p, 3.0, Color(1.0, 0.6902, 0.1686), true)
		"puddle", "blood_pool":
			draw_circle(p, 20.0 * sc, Color(0.45, 0.02, 0.09, 0.25) if kind == "blood_pool" else Color(0.1, 0.2, 0.35, 0.25))
		"shells":
			for i in range(5):
				draw_circle(p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)), 2.0, Color(0.7843, 0.6353, 0.2902))
		"neon_sign":
			_neon_sign(p, prop, rng)
		"vending_machine":
			draw_rect(Rect2(p - Vector2(18, 24), Vector2(36, 48)), Color(0.0784, 0.1098, 0.1569), true)
			draw_rect(Rect2(p - Vector2(12, 18), Vector2(24, 24)), Color(0.2, 0.8, 1.0, 0.25), true)
			draw_rect(Rect2(p - Vector2(18, 24), Vector2(36, 48)), Color(0.1686, 0.2275, 0.302), false, 2.0)
		"phone_booth":
			draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color(0.0627, 0.0941, 0.1255), true)
			draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color(0.2078, 0.7882, 1.0), false, 2.0)
		"shelf":
			var r := Rect2(p - Vector2(28, 10), Vector2(56, 20))
			draw_rect(r, Color(0.1373, 0.1137, 0.0902), true)
			for i in range(4):
				draw_rect(Rect2(r.position + Vector2(4 + i * 13, 3), Vector2(9, 14)), Color(0.7, 0.65, 0.5, 0.35), true)
			draw_rect(r, Color(0.2392, 0.2, 0.1529), false, 2.0)
		"fridge":
			draw_rect(Rect2(p - Vector2(24, 18), Vector2(48, 36)), Color(0.0549, 0.1098, 0.1333), true)
			draw_rect(Rect2(p - Vector2(20, 14), Vector2(40, 28)), Color(0.4, 0.9, 1.0, 0.15), true)
			draw_rect(Rect2(p - Vector2(24, 18), Vector2(48, 36)), Color(0.1137, 0.1961, 0.2392), false, 2.0)
		"counter", "desk":
			var r2 := Rect2(p - Vector2(30, 16), Vector2(60, 32))
			draw_rect(r2, Color(0.1647, 0.1333, 0.102), true)
			draw_rect(r2, Color(0.2667, 0.2118, 0.149), false, 2.0)
			draw_rect(Rect2(p - Vector2(10, 6), Vector2(20, 12)), Color(0.2, 0.9, 1.0, 0.15), true)
		"register":
			draw_rect(Rect2(p - Vector2(16, 12), Vector2(32, 24)), Color(0.102, 0.102, 0.1255), true)
			draw_rect(Rect2(p - Vector2(10, 6), Vector2(20, 8)), Color(0.3, 1.0, 0.6, 0.3), true)
		"crate", "pallet":
			var r3 := Rect2(p - Vector2(22, 22), Vector2(44, 44))
			draw_rect(r3, Color(0.1686, 0.1412, 0.098), true)
			draw_rect(r3, Color(0.2902, 0.2471, 0.1569), false, 3.0)
			draw_line(r3.position, r3.position + r3.size, Color(0.2902, 0.2471, 0.1569), 2.0)
		"barrel":
			draw_circle(p, 18.0, Color(0.1647, 0.102, 0.0706), true)
			draw_circle(p, 18.0, Color(1.0, 0.6902, 0.1686), false, 3.0)
			draw_circle(p, 6.0, Color(0.0471, 0.0314, 0.0235), true)
		"gurney":
			var r4 := Rect2(p - Vector2(14, 28), Vector2(28, 56))
			draw_rect(r4, Color(0.1255, 0.1882, 0.2275), true)
			draw_rect(r4, Color(0.749, 0.9373, 1.0), false, 2.0)
			draw_rect(Rect2(p - Vector2(10, 24), Vector2(20, 20)), Color(0.6, 0.95, 1.0, 0.15), true)
		"iv_stand":
			draw_circle(p, 5.0, Color(0.6667, 0.8667, 1.0), true)
			draw_line(p, p + Vector2(0, 18), Color(0.4824, 0.5608, 0.6039), 2.0)
		"chair":
			draw_circle(p, 14.0, Color(0.1098, 0.102, 0.1412), true)
			draw_circle(p, 14.0, Color(0.2, 0.1882, 0.2471), false, 2.0)
			draw_circle(p, 5.0, Color(0.1451, 0.1333, 0.1922), true)
		"trash":
			draw_circle(p, 11.0, Color(0.102, 0.1137, 0.1333), true)
			draw_circle(p, 11.0, Color(0.2, 0.2196, 0.2471), false, 2.0)
			draw_circle(p, 3.0, Color(0.7, 0.2, 0.2, 0.6), true)
		"plant":
			draw_circle(p, 15.0, Color(0.0706, 0.1882, 0.1216), true)
			for i in range(5):
				draw_line(p, p + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16)), Color(0.1216, 0.3529, 0.2078), 3.0)
		"monitor":
			draw_rect(Rect2(p - Vector2(16, 10), Vector2(32, 20)), Color(0.0431, 0.0667, 0.0941), true)
			draw_rect(Rect2(p - Vector2(13, 7), Vector2(26, 14)), Color(0.2, 0.9, 0.7, 0.22), true)
		"cabinet", "locker":
			var r5 := Rect2(p - Vector2(20, 22), Vector2(40, 44))
			draw_rect(r5, Color(0.102, 0.1216, 0.1569), true)
			draw_line(r5.position + Vector2(20, 0), r5.position + Vector2(20, 44), Color(0.1765, 0.2039, 0.2588), 2.0)
			draw_rect(r5, Color(0.1765, 0.2039, 0.2588), false, 2.0)
		"cash_rack", "safe":
			draw_rect(Rect2(p - Vector2(26, 26), Vector2(52, 52)), Color(0.102, 0.1137, 0.1412), true)
			draw_circle(p, 15.0, Color(0.1686, 0.1882, 0.2275), true)
			draw_circle(p, 15.0, Color(1.0, 0.6902, 0.1686), false, 3.0)
			draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color(1.0, 0.6902, 0.1686), 3.0)
		"vault_door":
			draw_circle(p, 30.0, Color(0.1373, 0.1569, 0.2), true)
			draw_circle(p, 30.0, Color(1.0, 0.6902, 0.1686), false, 4.0)
			draw_line(p + Vector2(-18, 0), p + Vector2(18, 0), Color(1.0, 0.6902, 0.1686), 4.0)
			draw_line(p + Vector2(0, -18), p + Vector2(0, 18), Color(1.0, 0.6902, 0.1686), 4.0)
		"chandelier":
			draw_circle(p, 26.0, Color(1.0, 0.85, 0.5, 0.12), true)
			draw_circle(p, 12.0, Color(1.0, 0.9, 0.6, 0.4), true)
		"bench":
			var r6 := Rect2(p - Vector2(34, 9), Vector2(68, 18))
			draw_rect(r6, Color(0.1647, 0.1412, 0.098), true)
			draw_rect(r6, Color(0.2902, 0.2471, 0.1569), false, 2.0)
		"mannequin":
			draw_circle(p, 12.0, Color(0.7843, 0.7255, 0.5412), true)
			draw_circle(p, 4.0, Color(0.1647, 0.1176, 0.0863), true)
		"kiosk":
			draw_rect(Rect2(p - Vector2(24, 24), Vector2(48, 48)), Color(0.1059, 0.0824, 0.1412), true)
			draw_rect(Rect2(p - Vector2(24, 24), Vector2(48, 48)), Color(1.0, 0.1686, 0.8392), false, 2.0)
		"fountain":
			draw_circle(p, 28.0, Color(0.0471, 0.0941, 0.149), true)
			draw_circle(p, 28.0, Color(0.2, 0.6, 1.0, 0.15), false, 3.0)
			draw_circle(p, 8.0, Color(0.102, 0.1725, 0.251), true)
		"escalator":
			var r7 := Rect2(p - Vector2(24, 60), Vector2(48, 120))
			draw_rect(r7, Color(0.0784, 0.0863, 0.1216), true)
			for i in range(8):
				draw_line(Vector2(r7.position.x, r7.position.y + i * 15), Vector2(r7.end.x, r7.position.y + i * 15), Color(0.6, 0.8, 1.0, 0.06), 2.0)
		"projector":
			draw_rect(Rect2(p - Vector2(14, 10), Vector2(28, 20)), Color(0.102, 0.0784, 0.1255), true)
			draw_circle(p + Vector2(12, 0), 5.0, Color(0.9, 0.9, 1.0, 0.6), true)
		"seat_row":
			var r8 := Rect2(p - Vector2(56, 16), Vector2(112, 32))
			draw_rect(r8, Color(0.1647, 0.0588, 0.1137), true)
			for i in range(6):
				draw_rect(Rect2(r8.position + Vector2(2 + i * 18, 4), Vector2(15, 24)), Color(0.2392, 0.0784, 0.1569), true)
		"curtain":
			var r9 := Rect2(p - Vector2(60, 10), Vector2(120, 20))
			draw_rect(r9, Color(0.2392, 0.0588, 0.1412), true)
			for i in range(12):
				draw_line(Vector2(r9.position.x + i * 10, r9.position.y), Vector2(r9.position.x + i * 10, r9.end.y), Color(0, 0, 0, 0.3), 3.0)
		"popcorn":
			draw_rect(Rect2(p - Vector2(18, 10), Vector2(36, 20)), Color(0.2275, 0.1412, 0.0627), true)
			draw_rect(Rect2(p - Vector2(18, 10), Vector2(36, 20)), Color(1.0, 0.6902, 0.1686), false, 2.0)
		"poster":
			draw_rect(Rect2(p - Vector2(18, 26), Vector2(36, 52)), Color(0.102, 0.0588, 0.1333), true)
			draw_rect(Rect2(p - Vector2(14, 22), Vector2(28, 30)), Color(0.8, 0.2, 0.6, 0.25), true)
		"desk_pc":
			draw_rect(Rect2(p - Vector2(26, 14), Vector2(52, 28)), Color(0.1333, 0.1255, 0.1686), true)
			draw_rect(Rect2(p - Vector2(8, 6), Vector2(16, 10)), Color(0.3, 1.0, 0.8, 0.3), true)
		"blackboard":
			var rb := Rect2(p - Vector2(56, 14), Vector2(112, 28))
			draw_rect(rb, Color(0.0549, 0.102, 0.0784), true)
			draw_line(rb.position + Vector2(8, 8), rb.position + Vector2(60, 14), Color(0.8, 0.9, 0.85, 0.3), 2.0)
			draw_line(rb.position + Vector2(20, 20), rb.position + Vector2(90, 18), Color(0.8, 0.9, 0.85, 0.2), 2.0)
		"backpack":
			draw_rect(Rect2(p - Vector2(10, 12), Vector2(20, 24)), Color(0.1686, 0.1216, 0.2275), true)
			draw_rect(Rect2(p - Vector2(10, 12), Vector2(20, 24)), Color(0.5529, 0.1686, 1.0), false, 2.0)
		"basketball_hoop":
			draw_circle(p, 10.0, Color(1.0, 0.4784, 0.1216), false, 3.0)
			draw_line(p, p + Vector2(0, -20), Color(0.4824, 0.4706, 0.5647), 3.0)
		"ac_unit":
			draw_rect(Rect2(p - Vector2(34, 34), Vector2(68, 68)), Color(0.1098, 0.1333, 0.1686), true)
			draw_circle(p, 24.0, Color(0.0706, 0.0863, 0.1137), true)
			for i in range(4):
				draw_arc(p, 18.0, i * 1.57, i * 1.57 + 0.9, 8, Color(0.2275, 0.2667, 0.3137), 3.0)
			draw_rect(Rect2(p - Vector2(34, 34), Vector2(68, 68)), Color(0.1765, 0.2118, 0.2588), false, 2.0)
		"vent":
			draw_rect(Rect2(p - Vector2(28, 20), Vector2(56, 40)), Color(0.0824, 0.102, 0.1294), true)
			for i in range(4):
				draw_line(p + Vector2(-24, -12 + i * 8), p + Vector2(24, -12 + i * 8), Color(0.1843, 0.2235, 0.2706), 3.0)
		"dish":
			draw_circle(p, 26.0, Color(0.1255, 0.149, 0.1843), true)
			draw_circle(p, 26.0, Color(0.2275, 0.2667, 0.3137), false, 2.0)
			draw_line(p, p + Vector2(18, -18), Color(0.2275, 0.2667, 0.3137), 3.0)
		"water_tank":
			draw_circle(p, 40.0, Color(0.0824, 0.1059, 0.1333), true)
			draw_circle(p, 40.0, Color(0.1686, 0.2039, 0.251), false, 3.0)
			draw_circle(p, 12.0, Color(0.0431, 0.0588, 0.0784), true)
		"container":
			draw_rect(Rect2(p - Vector2(40, 26), Vector2(80, 52)), Color(0.1216, 0.1686, 0.1216), true)
			for i in range(6):
				draw_line(p + Vector2(-36 + i * 14, -22), p + Vector2(-36 + i * 14, 22), Color(0, 0, 0, 0.25), 3.0)
		"forklift":
			draw_rect(Rect2(p - Vector2(24, 30), Vector2(48, 60)), Color(0.1686, 0.1451, 0.0706), true)
			draw_rect(Rect2(p - Vector2(10, 10), Vector2(20, 20)), Color(0.0471, 0.0392, 0.0196), true)
			draw_rect(Rect2(p + Vector2(-4, -30), Vector2(8, 20)), Color(0.4824, 0.4706, 0.5647), true)
		"piano":
			draw_rect(Rect2(p - Vector2(40, 26), Vector2(80, 52)), Color(0.0471, 0.0431, 0.0667), true)
			for i in range(8):
				draw_rect(Rect2(p + Vector2(-38 + i * 9, -20), Vector2(7, 18)), Color(0.9098, 0.8902, 0.8353), true)
		"couch":
			draw_rect(Rect2(p - Vector2(40, 26), Vector2(80, 52)), Color(0.1412, 0.0706, 0.149), true)
			draw_rect(Rect2(p - Vector2(32, 18), Vector2(64, 36)), Color(0.2, 0.102, 0.2118), true)
		"bar":
			draw_rect(Rect2(p - Vector2(50, 18), Vector2(100, 36)), Color(0.102, 0.0706, 0.0941), true)
			for i in range(6):
				draw_rect(Rect2(p + Vector2(-44 + i * 15, -12), Vector2(6, 12)), Color(0.6, 0.3, 0.8, 0.4), true)
		"glass_wall":
			draw_rect(Rect2(p - Vector2(58, 14), Vector2(116, 28)), Color(0.2, 0.4, 0.6, 0.08), true)
			draw_rect(Rect2(p - Vector2(58, 14), Vector2(116, 28)), Color(0.2196, 0.3333, 0.4275), false, 2.0)
		"toilet":
			draw_circle(p, 12.0, Color(0.7216, 0.7686, 0.8), true)
			draw_circle(p, 6.0, Color(0.2275, 0.2745, 0.3137), true)
		"bars":
			var rb2 := Rect2(p - Vector2(30, 30), Vector2(60, 60))
			for i in range(6):
				draw_line(Vector2(rb2.position.x + i * 12, rb2.position.y), Vector2(rb2.position.x + i * 12, rb2.end.y), Color(0.3529, 0.3843, 0.4392), 4.0)
		"evidence_board":
			draw_rect(Rect2(p - Vector2(60, 20), Vector2(120, 40)), Color(0.1686, 0.1137, 0.0784), true)
			for i in range(5):
				draw_rect(Rect2(p + Vector2(-52 + i * 22, -14), Vector2(16, 22)), Color(0.9098, 0.8902, 0.8353), true)
				draw_line(p + Vector2(-44 + i * 22, -14), p + Vector2(-30 + i * 22, 10), Color(1.0, 0.1686, 0.3843), 1.0)
		"knife_block":
			draw_rect(Rect2(p - Vector2(20, 12), Vector2(40, 24)), Color(0.1098, 0.102, 0.0863), true)
			for i in range(4):
				draw_line(p + Vector2(-14 + i * 9, -8), p + Vector2(-14 + i * 9, 8), Color(0.5412, 0.5608, 0.5882), 2.0)
		"table":
			draw_circle(p, 24.0, Color(0.1647, 0.1333, 0.102), true)
			draw_circle(p, 24.0, Color(0.2667, 0.2118, 0.149), false, 2.0)
		"camera_rig":
			draw_circle(p, 12.0, Color(0.102, 0.1216, 0.1569), true)
			draw_circle(p, 5.0, Color(1, 0.2, 0.2, 0.8), true)
		"ashtray":
			draw_circle(p, 9.0, Color(0.1333, 0.149, 0.1765), true)
			draw_circle(p, 3.0, Color(1, 0.5, 0.2, 0.7), true)
		"printer":
			draw_rect(Rect2(p - Vector2(20, 14), Vector2(40, 28)), Color(0.1176, 0.1294, 0.1608), true)
			draw_rect(Rect2(p - Vector2(20, 14), Vector2(40, 6)), Color(0.1725, 0.1882, 0.2275), true)
		"copier":
			draw_rect(Rect2(p - Vector2(24, 18), Vector2(48, 36)), Color(0.1059, 0.1216, 0.1529), true)
			draw_rect(Rect2(p - Vector2(10, 4), Vector2(20, 6)), Color(0.2, 0.9, 0.5, 0.5), true)
		_:
			draw_circle(p, 10.0, Color(0.5, 0.5, 0.6, 0.4), true)


## Each lit sign owns one small Sprite2D carrying shaders/neon_sign.gdshader:
## the tube flicker, the glitch slice and the two-colour emission animate there,
## while the flat neon geometry stays baked into the painter.
func _spawn_sign_shader(p: Vector2, prop: Dictionary, col: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var shader: Shader = load("res://shaders/neon_sign.gdshader")
	if shader == null:
		return
	# 1x1 white sprite stretched over the tube: the shader reads the texture
	# luminance as the tube mask, so a filled rect IS the tube.
	var img := Image.create(8, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var node := Sprite2D.new()
	node.name = "SignGlow"
	node.texture = ImageTexture.create_from_image(img)
	node.position = p + Vector2(10, 0)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sign_color", col)
	mat.set_shader_parameter("backup_color", Color("35c9ff") if col.r > 0.5 else Color("ff2bd6"))
	mat.set_shader_parameter("glow", 1.6)
	mat.set_shader_parameter("flicker_chance", 0.25 + float(prop.get("flicker", 0.0)) * 0.5)
	mat.set_shader_parameter("glitch", 0.12)
	node.material = mat
	node.z_index = 2
	node.scale = Vector2(1.6, 1.0)
	parent.call_deferred("add_child", node)


func _car(p: Vector2, rot: float, sc: float) -> void:
	var w := 78.0 * sc
	var h := 38.0 * sc
	draw_set_transform(p, rot, Vector2.ONE)
	var body := Color(0.0824, 0.102, 0.149)
	draw_rect(Rect2(-Vector2(w, h) * 0.5, Vector2(w, h)), body, true)
	draw_rect(Rect2(-Vector2(w, h) * 0.5, Vector2(w, h)), Color(0.1843, 0.2275, 0.302), false, 2.0)
	draw_rect(Rect2(-Vector2(w * 0.28, h * 0.36), Vector2(w * 0.5, h * 0.72)), Color(0.2, 0.35, 0.5, 0.5), true)
	draw_rect(Rect2(-Vector2(w * 0.42, h * 0.4), Vector2(w * 0.1, h * 0.8)), Color(0.8, 0.2, 0.2, 0.5), true)
	draw_circle(Vector2(w * 0.46, 0), 4.0, Color(1, 0.95, 0.7, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _neon_sign(p: Vector2, prop: Dictionary, rng: RandomNumberGenerator) -> void:
	var col := Color(str(prop.get("color", "#ff2b62")))
	# A dead tube cycles off for a beat; the shader does that flicker on the GPU,
	# here we only drop the painted fallback so both versions agree.
	draw_set_transform(p, float(prop.get("rot", 0.0)) * 0.0, Vector2.ONE)
	for i in range(3):
		draw_rect(Rect2(p + Vector2(-8 + i * 20, -14), Vector2(10, 28)), Color(col.r, col.g, col.b, 0.22), true)
	draw_line(p + Vector2(-30, 0), p + Vector2(50, 0), Color(col.r, col.g, col.b, 0.5), 3.0)
	draw_circle(p + Vector2(50, 0), 6.0, Color(col.r, col.g, col.b, 0.6), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_spawn_sign_shader(p, prop, col)
