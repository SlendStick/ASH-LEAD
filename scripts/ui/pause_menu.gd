class_name PauseMenu
extends CanvasLayer
## Pause overlay: resume, settings, leave match.

signal resume_requested
signal settings_requested
signal leave_requested

var panel: PanelContainer
var _open: bool = false


func _ready() -> void:
	layer = 8
	_build()
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(960 - 240, 300)
	panel.custom_minimum_size = Vector2(480, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.065, 0.97)
	style.border_color = Color(0.25, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = Localization.t("pause_title")
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for entry in [
		{"signal": "resume_requested", "key": "pause_resume"},
		{"signal": "settings_requested", "key": "pause_settings"},
		{"signal": "leave_requested", "key": "pause_leave"},
	]:
		var button := Button.new()
		button.text = Localization.t(entry["key"])
		button.custom_minimum_size = Vector2(420, 52)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_button.bind(String(entry["signal"])))
		box.add_child(button)


func open() -> void:
	_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.ui_click()


func close() -> void:
	_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func is_open() -> bool:
	return _open


func _on_button(signal_name: String) -> void:
	AudioManager.ui_click()
	match signal_name:
		"resume_requested":
			close()
			resume_requested.emit()
		"settings_requested":
			settings_requested.emit()
		"leave_requested":
			close()
			leave_requested.emit()
