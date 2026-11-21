extends Control
## Radial squad-order wheel. Hold C (or press C then aim right-click) to order all
## bots of your team: PUSH / FLANK / HOLD / RETREAT. Also draws the small "M"
## world ping helper text.

var world: Node
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := 150.0
	draw_circle(center, radius + 34.0, Color(0.02, 0.015, 0.04, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.4, 0.9, 1.0, 0.25), 2.0)
	draw_arc(center, radius * 0.55, 0.0, TAU, 48, Color(0.4, 0.9, 1.0, 0.12), 1.0)
	var labels := ["ВПЕРЁД", "ОБХОД", "ДЕРЖАТЬ", "ОТСТУП"]
	var colors := [Color("ff2b62"), Color("ffb02b"), Color("35c9ff"), Color("2bff9a")]
	var mouse := get_local_mouse_position()
	var dir := mouse - center
	var hover := -1
	if dir.length() > 24.0:
		var ang := dir.angle() + PI * 0.5
		if ang < 0:
			ang += TAU
		hover = int(round(ang / (TAU / 4.0))) % 4
	for i in range(4):
		var ang0 := -PI * 0.5 + i * TAU / 4.0 - TAU / 8.0
		var ang1 := ang0 + TAU / 4.0
		var col: Color = colors[i]
		var alpha := 0.5 if hover == i else 0.16
		var pts := PackedVector2Array([center])
		for k in range(9):
			var a := ang0 + (ang1 - ang0) * float(k) / 8.0
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.10 + (0.14 if hover == i else 0.0)))
		draw_arc(center, radius, ang0, ang1, 16, Color(col.r, col.g, col.b, alpha), 2.0)
		var mid := (ang0 + ang1) * 0.5
		var lp := center + Vector2(cos(mid), sin(mid)) * radius * 0.72
		draw_string(ThemeDB.fallback_font, lp - Vector2(38, 0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, 78, 15, Color(col.r, col.g, col.b, 0.95 if hover == i else 0.6))
	draw_string(ThemeDB.fallback_font, center + Vector2(-46, 52), "ПРИКАЗ ОТРЯДУ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.85, 1.0, 0.8))
	draw_string(ThemeDB.fallback_font, center + Vector2(-60, 74), "ПКМ или C — выбрать", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.7, 0.85, 0.6))
