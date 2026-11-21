extends CanvasLayer
## Global UI overlay: notifications, screen fade, custom crosshair cursor, hints.
## Lives above everything so scene swaps never orphan a toast.

var root: Control
var toast_box: VBoxContainer
var fade: ColorRect
var hint: Label
var cursor: Control
var vignette: Control
var vignette_rect: ColorRect = null
var _pulse := 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		pass


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	fade = ColorRect.new()
	fade.color = Color(0.02, 0.01, 0.04, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	toast_box = VBoxContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-260, 46)
	toast_box.custom_minimum_size = Vector2(520, 0)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-420, -150)
	hint.custom_minimum_size = Vector2(840, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.8))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate.a = 0.0
	root.add_child(hint)

	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vshader: Shader = load("res://shaders/vignette_pulse.gdshader")
	if vshader != null:
		var vmat := ShaderMaterial.new()
		vmat.shader = vshader
		vignette.material = vmat
		vignette_rect = vignette
	Signals.notify.connect(_on_notify)


func _on_notify(text: String, kind: String) -> void:
	var colors := {
		"info": Color("35c9ff"), "good": Color("2bff9a"), "bad": Color("ff1f4b"),
		"money": Color("ffb02b"), "warning": Color("ff2bd6"),
	}
	var col: Color = colors.get(kind, Color("35c9ff"))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.06, 0.88)
	sb.border_width_left = 4
	sb.border_color = col
	sb.content_margin_left = 14
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.25))
	panel.add_child(lbl)
	toast_box.add_child(panel)
	while toast_box.get_child_count() > 6:
		var old_toast := toast_box.get_child(0)
		toast_box.remove_child(old_toast)
		old_toast.queue_free()
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.6 + text.length() * 0.01)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free())


func fade_to_black(seconds: float = 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, seconds)


func fade_from_black(seconds: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, seconds)


func show_hint(text: String, seconds: float = 3.5) -> void:
	hint.text = text
	var tw := create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.2)
	tw.tween_interval(seconds)
	tw.tween_property(hint, "modulate:a", 0.0, 0.6)


func set_loading_text(text: String) -> void:
	hint.text = text
	hint.modulate.a = 1.0


# ---------------------------------------------------------------------------
# VIGNETTE / PULSE (low health, alarm, damage)
# ---------------------------------------------------------------------------

## 0..1 strength for the heartbeat vignette; called by the HUD each frame.
func set_pulse(amount: float) -> void:
	_pulse = clampf(amount, 0.0, 1.0)
	if vignette_rect != null and vignette_rect.material is ShaderMaterial:
		(vignette_rect.material as ShaderMaterial).set_shader_parameter("pulse", _pulse)


func _process(_delta: float) -> void:
	if vignette_rect == null:
		return
	vignette_rect.visible = _pulse > 0.01
