class_name NeonBackground
extends Control
## Animated menu backdrop: a rain-slick city skyline, drifting neon haze, moving
## light beams and CRT noise. Deliberately cheap (a few thousand draw calls per
## frame) but it carries the whole art direction: cold blue night, magenta signs.

var t := 0.0
var buildings: Array[Dictionary] = []
var rain: Array[Dictionary] = []
var signs: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var neon := [Color("ff2b62"), Color("35c9ff"), Color("8d2bff"), Color("2bff9a"), Color("ff2bd6")]
var rng := RandomNumberGenerator.new()
var intensity := 1.0
var mode := "menu"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.seed = 424242
	_generate()
	set_process(true)


func _generate() -> void:
	buildings.clear()
	var x := -60.0
	while x < 2400.0:
		var w := rng.randf_range(70.0, 190.0)
		var h := rng.randf_range(180.0, 620.0)
		buildings.append({
			"x": x, "w": w, "h": h,
			"col": Color(0.04, 0.035, 0.07).lerp(Color(0.07, 0.06, 0.11), rng.randf()),
			"windows": rng.randi_range(8, 30),
			"sign": rng.randf() < 0.3,
			"neon": neon[rng.randi_range(0, neon.size() - 1)],
		})
		x += w + rng.randf_range(10.0, 50.0)
	rain.clear()
	for i in range(180):
		rain.append({"x": rng.randf_range(0, 2000), "y": rng.randf_range(0, 1200), "len": rng.randf_range(12, 34), "sp": rng.randf_range(500, 1200), "a": rng.randf_range(0.05, 0.22)})
	beams.clear()
	for i in range(6):
		beams.append({"x": rng.randf_range(0, 2000), "y": rng.randf_range(-100, 400), "ang": rng.randf_range(-0.6, 0.6), "len": rng.randf_range(600, 1400), "col": neon[rng.randi_range(0, neon.size() - 1)], "sp": rng.randf_range(0.02, 0.08)})


func _process(delta: float) -> void:
	t += delta
	var sz := size
	if sz.x < 10:
		return
	# move rain
	for r in rain:
		r["y"] = float(r["y"]) + float(r["sp"]) * delta * intensity
		r["x"] = float(r["x"]) - 120.0 * delta
		if float(r["y"]) > sz.y + 40:
			r["y"] = -40.0
			r["x"] = rng.randf_range(-200, sz.x + 200)
		if float(r["x"]) < -220:
			r["x"] = sz.x + 200
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x < 4:
		return
	# deep night gradient
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.015, 0.011, 0.03), true)
	for i in range(12):
		var a := float(i) / 12.0
		var c := Color(0.03, 0.02, 0.08).lerp(Color(0.10, 0.03, 0.12), a)
		draw_rect(Rect2(0, sz.y * 0.35 + a * sz.y * 0.5, sz.x, sz.y * 0.06), Color(c.r, c.g, c.b, 0.5), true)
	# moon / industrial glow
	draw_circle(Vector2(sz.x * 0.78, sz.y * 0.18), 120.0, Color(0.35, 0.15, 0.5, 0.06))
	draw_circle(Vector2(sz.x * 0.78, sz.y * 0.18), 52.0, Color(0.9, 0.85, 0.95, 0.08))
	# skyline
	var ground := sz.y * 0.82
	for b in buildings:
		var bx := float(b["x"]) - fmod(t * 6.0, 300.0) * 0.0
		var bw := float(b["w"])
		var bh := float(b["h"])
		var by := ground - bh
		if bx > sz.x + 100 or bx + bw < -100:
			continue
		draw_rect(Rect2(bx, by, bw, bh + 200), b["col"], true)
		# windows
		var wn: int = b["windows"]
		for k in range(wn):
			var wx := bx + 10 + fmod(k * 37.0, bw - 20)
			var wy := by + 18 + fmod(k * 53.0, max(20.0, bh - 40))
			var lit := fmod(k * 7.3 + b["x"], 3.0) < 1.0
			if lit:
				draw_rect(Rect2(wx, wy, 7, 11), Color(1.0, 0.85, 0.55, 0.16), true)
		# neon sign on the facade
		if bool(b["sign"]):
			var sc: Color = b["neon"]
			var sy := by + 40 + fmod(float(b["x"]), 120.0)
			var flick := 0.6 + 0.4 * sin(t * 3.0 + float(b["x"]))
			draw_rect(Rect2(bx + bw * 0.2, sy, bw * 0.6, 14), Color(sc.r, sc.g, sc.b, 0.25 * flick), true)
			draw_rect(Rect2(bx + bw * 0.2, sy, bw * 0.6, 14), Color(sc.r, sc.g, sc.b, 0.5 * flick), false, 1.5)
			draw_circle(Vector2(bx + 6, sy + 7), 26.0, Color(sc.r, sc.g, sc.b, 0.05 * flick))
	# light beams through rain
	for bm in beams:
		var bx2 := float(bm["x"]) + sin(t * float(bm["sp"]) * 6.0) * 60.0
		var col: Color = bm["col"]
		var ang := float(bm["ang"])
		var len := float(bm["len"])
		var poly := PackedVector2Array([
			Vector2(bx2, float(bm["y"])),
			Vector2(bx2 + cos(ang - 0.08) * len, float(bm["y"]) + sin(ang - 0.08) * len),
			Vector2(bx2 + cos(ang + 0.08) * len, float(bm["y"]) + sin(ang + 0.08) * len),
		])
		draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.02))
	# wet street
	draw_rect(Rect2(0, ground, sz.x, sz.y - ground), Color(0.02, 0.018, 0.035), true)
	for i in range(7):
		var y := ground + 12 + i * 22
		draw_rect(Rect2(0, y, sz.x, 8), Color(0.06, 0.02, 0.08, 0.25 - i * 0.03), true)
	draw_line(Vector2(0, ground), Vector2(sz.x, ground), Color(0.5, 0.2, 0.6, 0.15), 2.0)
	# rain
	for r in rain:
		var p := Vector2(float(r["x"]), float(r["y"]))
		draw_line(p, p + Vector2(-4, -float(r["len"])), Color(0.7, 0.85, 1.0, float(r["a"])), 1.0)
	# scanline noise
	for y in range(0, int(sz.y), 4):
		draw_line(Vector2(0, y), Vector2(sz.x, y), Color(0, 0, 0, 0.10), 1.0)
	# vignette
	draw_rect(Rect2(0, 0, sz.x, 90), Color(0, 0, 0, 0.45), true)
	draw_rect(Rect2(0, sz.y - 130, sz.x, 130), Color(0, 0, 0, 0.55), true)
