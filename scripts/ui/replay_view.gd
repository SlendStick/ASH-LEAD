class_name ReplayView
extends Control
## Skippable highlight replay built from real recorded match snapshots.

signal closed

var highlight: Dictionary = {}
var frames: Array = []
var sprites: Dictionary = {}
var ground: Node2D
var title_label: Label
var time_label: Label
var skip_button: Button
var close_button: Button
var elapsed: float = 0.0
var duration: float = 7.0
var finished: bool = false
var _close_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func open(highlight_data: Dictionary, replay_frames: Array) -> void:
	highlight = highlight_data
	frames = replay_frames
	elapsed = 0.0
	finished = false
	duration = 7.0
	if highlight.has("duration"):
		duration = float(highlight["duration"])
	_center_camera()
	_spawn_sprites()
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.play("objective", Vector2.INF, -10.0)


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.014, 0.024, 0.96)
	add_child(dim)
	ground = Node2D.new()
	add_child(ground)
	title_label = Label.new()
	title_label.position = Vector2(960 - 300, 30)
	title_label.custom_minimum_size = Vector2(600, 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	add_child(title_label)
	time_label = Label.new()
	time_label.position = Vector2(960 - 100, 90)
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.modulate = Color(0.6, 0.8, 0.9)
	add_child(time_label)
	skip_button = Button.new()
	skip_button.text = Localization.t("replay_skip")
	skip_button.position = Vector2(960 - 110, 1000)
	skip_button.custom_minimum_size = Vector2(220, 48)
	skip_button.pressed.connect(_close)
	add_child(skip_button)
	close_button = Button.new()
	close_button.text = Localization.t("back")
	close_button.position = Vector2(60, 1000)
	close_button.custom_minimum_size = Vector2(160, 48)
	close_button.pressed.connect(_close)
	add_child(close_button)


func _center_camera() -> void:
	for child in ground.get_children():
		child.queue_free()
	if frames.is_empty():
		return
	var first: Dictionary = frames[0]
	var center := Vector2.ZERO
	var count := 0
	for c in first["chars"]:
		center += Vector2(c["pos"])
		count += 1
	if count > 0:
		center /= float(count)
		ground.position = Vector2(960, 540) - center
	# Ground grid
	for i in range(-20, 21):
		var line_h := Line2D.new()
		line_h.points = PackedVector2Array([Vector2(-2000, i * 64.0), Vector2(2000, i * 64.0)])
		line_h.width = 1.0
		line_h.default_color = Color(0.12, 0.18, 0.22, 0.5)
		ground.add_child(line_h)
		var line_v := Line2D.new()
		line_v.points = PackedVector2Array([Vector2(i * 64.0, -2000), Vector2(i * 64.0, 2000)])
		line_v.width = 1.0
		line_v.default_color = Color(0.12, 0.18, 0.22, 0.5)
		ground.add_child(line_v)


func _spawn_sprites() -> void:
	for key in sprites:
		var node: Node2D = sprites[key]
		if is_instance_valid(node):
			node.queue_free()
	sprites.clear()
	if frames.is_empty():
		return
	var names := {}
	for f in frames:
		for c in f["chars"]:
			names[c["name"]] = c["team"]
	for name in names:
		var sprite := Sprite2D.new()
		var team: int = names[name]
		var prefix := "char_crim_1" if team == GameTypes.Team.CRIMINALS else "char_cop_patrol"
		sprite.texture = load("res://assets/textures/%s.png" % prefix)
		sprite.z_index = 5
		ground.add_child(sprite)
		sprites[name] = sprite
	title_label.text = Localization.t(String(highlight.get("title_key", "highlight_last_kill")))


func _process(delta: float) -> void:
	if not visible:
		return
	if not finished:
		elapsed += delta
		_apply_frame()
		time_label.text = "%s %d:%02d" % [Localization.t("replay_time"), int(elapsed) / 60, int(elapsed) % 60]
		if elapsed >= duration:
			finished = true
			_close_timer = 1.4
			time_label.text = Localization.t("replay_end")
	else:
		_close_timer -= delta
		if _close_timer <= 0.0:
			_close()


func _apply_frame() -> void:
	if frames.is_empty():
		return
	var t := elapsed
	var a: Dictionary = frames[0]
	var b: Dictionary = frames[0]
	for i in frames.size():
		if float(frames[i]["t"]) <= t:
			a = frames[i]
		else:
			b = frames[i]
			break
	var span := maxf(0.001, float(b["t"]) - float(a["t"]))
	var alpha := clampf((t - float(a["t"])) / span, 0.0, 1.0)
	var pos_a := {}
	var pos_b := {}
	var aim_a := {}
	var aim_b := {}
	for c in a["chars"]:
		pos_a[c["name"]] = c["pos"]
		aim_a[c["name"]] = c["aim"]
	for c in b["chars"]:
		pos_b[c["name"]] = c["pos"]
		aim_b[c["name"]] = c["aim"]
	for name in sprites:
		if pos_a.has(name) and pos_b.has(name):
			var sprite: Sprite2D = sprites[name]
			sprite.position = (pos_a[name] as Vector2).lerp(pos_b[name], alpha)
			sprite.rotation = lerp_angle(float(aim_a[name]), float(aim_b.get(name, aim_a[name])), alpha)


func _close() -> void:
	visible = false
	closed.emit()
