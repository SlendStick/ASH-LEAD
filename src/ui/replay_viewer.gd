class_name ReplayViewer
extends Control
## "Killcam" playback of the buffered frames captured around a highlight.
## Re-renders actors as simple silhouettes in the neon palette with a CRT scanline
## filter, slow-motion and a big label ("ДВОЙНОЕ УБИЙСТВО + В ГОЛОВУ").

var clip: Dictionary = {}
var world: Node
var autoplay := true
var playing := true
var frame := 0.0
var speed := 1.0
var t := 0.0
var focus := Vector2.ZERO
var label := ""
var started := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	label = str(clip.get("label", ""))
	_start()


func _start() -> void:
	if clip.is_empty():
		return
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return
	frame = 0.0
	playing = true
	started = true


func _process(delta: float) -> void:
	t += delta
	if not started:
		return
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return
	if playing:
		frame += delta * 12.0 * speed
		if frame >= frames.size() - 1:
			frame = float(frames.size() - 1)
			playing = false
	# camera follows the killer of the final frame
	var idx := clampi(int(frame), 0, frames.size() - 1)
	var f: Dictionary = frames[idx]
	var killer_id := int(clip.get("killer_id", -1))
	var victim_id := int(clip.get("victim_id", -1))
	for a in f.get("a", []):
		if int(a[0]) == killer_id or int(a[0]) == victim_id:
			focus = focus.lerp(Vector2(float(a[1]), float(a[2])), 0.2)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.008, 0.02, 1.0), true)
	# grid background
	for x in range(0, int(size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.1, 0.2, 0.3, 0.15), 1.0)
	for y in range(0, int(size.y), 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.1, 0.2, 0.3, 0.15), 1.0)
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(20, 30), "НЕТ ЗАПИСИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.7, 0.8))
		return
	var idx := clampi(int(frame), 0, frames.size() - 1)
	var f: Dictionary = frames[idx]
	var center := size * 0.5
	var scale := 0.42
	var killer_id := int(clip.get("killer_id", -1))
	var victim_id := int(clip.get("victim_id", -1))
	var shot_moment := idx >= frames.size() - 7
	# draw actors
	for a in f.get("a", []):
		var p: Vector2 = center + (Vector2(float(a[1]), float(a[2])) - focus) * scale
		if p.x < -40 or p.x > size.x + 40 or p.y < -40 or p.y > size.y + 40:
			continue
		var team := int(a[6])
		var col: Color = Db.TEAM_COLORS.get(team, Color.WHITE)
		var is_dead := int(a[5]) == 1
		var facing := float(a[3])
		var aid := int(a[0])
		if aid == killer_id:
			col = col.lerp(Color.WHITE, 0.35 + 0.25 * sin(t * 8.0))
		if is_dead:
			col = Color(0.35, 0.35, 0.4, 0.6)
			draw_circle(p, 9.0, col)
			draw_circle(p, 14.0, Color(0.45, 0.0, 0.05, 0.35))
			continue
		draw_arc(p, 15.0, facing - 0.5, facing + 0.5, 12, Color(col.r, col.g, col.b, 0.35), 2.0)
		draw_circle(p, 10.0, col)
		draw_circle(p, 10.0, Color(0, 0, 0, 0.55), false, 2.0)
		draw_line(p, p + Vector2(cos(facing), sin(facing)) * 22.0, Color(0.85, 0.9, 1.0, 0.7), 2.5)
		draw_circle(p + Vector2(cos(facing), sin(facing)) * 10.0, 3.0, Color(1, 1, 1, 0.85))
		# tracer toward victim on the shot frame
		if aid == killer_id and shot_moment and victim_id >= 0:
			for b in f.get("a", []):
				if int(b[0]) == victim_id:
					var vp: Vector2 = center + (Vector2(float(b[1]), float(b[2])) - focus) * scale
					draw_line(p, vp, Color(1.0, 0.85, 0.4, 0.85), 2.0)
					draw_circle(vp, 8.0, Color(1.0, 0.2, 0.3, 0.5))
	# scanlines
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.14), 1.0)
	# vignette
	draw_rect(Rect2(0, 0, size.x, 36), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(0, size.y - 36, size.x, 36), Color(0, 0, 0, 0.6), true)
	# labels
	draw_string(ThemeDB.fallback_font, Vector2(16, 24), "REPLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.2, 0.8, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(16, 26 + 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.9, 0.95, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 14), "%s ▸ %s" % [clip.get("killer", ""), clip.get("victim", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.85, 0.95, 0.8))
	# progress bar
	var prog := float(idx) / maxf(1.0, float(frames.size() - 1))
	draw_rect(Rect2(0, size.y - 4, size.x, 4), Color(0.2, 0.2, 0.25, 0.6), true)
	draw_rect(Rect2(0, size.y - 4, size.x * prog, 4), Color(1.0, 0.2, 0.5, 0.9), true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not playing:
				_start()
			else:
				playing = not playing
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(2.0, speed + 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(0.25, speed - 0.25)
