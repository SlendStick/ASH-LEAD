class_name MainMenu
extends Control
## Main menu: rain-soaked neon city backdrop, sections and service status.

signal start_requested(screen: String)
signal quit_requested

var status_label: Label
var group_label: Label
var version_label: Label
var _rain: Rain


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	AudioManager.play_music("music_menu")
	AudioManager.play_ambient("ambient_rain")


func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/textures/bg_menu.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	_rain = Rain.new()
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rain)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.25)
	add_child(dim)
	# Logo
	var logo := Label.new()
	logo.text = "ASH&LEAD"
	logo.add_theme_font_size_override("font_size", 92)
	logo.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	logo.add_theme_color_override("font_outline_color", Color(0.85, 0.15, 0.3))
	logo.add_theme_constant_override("outline_size", 6)
	logo.position = Vector2(80, 90)
	add_child(logo)
	var subtitle := Label.new()
	subtitle.text = Localization.t("menu_subtitle")
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.35, 0.85, 0.8))
	subtitle.position = Vector2(86, 196)
	add_child(subtitle)
	# Sections
	var box := VBoxContainer.new()
	box.position = Vector2(90, 250)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	for entry in [
		{"screen": "mode_select", "key": "menu_play"},
		{"screen": "quick", "key": "menu_quick"},
		{"screen": "lobby_create", "key": "menu_lobby_create"},
		{"screen": "lobby_join", "key": "menu_lobby_join"},
		{"screen": "training", "key": "menu_training"},
		{"screen": "loadout", "key": "menu_operators"},
		{"screen": "profile", "key": "menu_profile"},
		{"screen": "collection", "key": "menu_collection"},
		{"screen": "settings", "key": "menu_settings"},
		{"screen": "credits", "key": "menu_credits"},
		{"screen": "quit", "key": "menu_quit"},
	]:
		var button := Button.new()
		button.text = Localization.t(entry["key"])
		button.custom_minimum_size = Vector2(340, 46)
		button.add_theme_font_size_override("font_size", 20)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_button.bind(String(entry["screen"])))
		box.add_child(button)
	# Status block
	var status_panel := PanelContainer.new()
	status_panel.anchor_left = 1.0
	status_panel.anchor_right = 1.0
	status_panel.anchor_top = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_left = -420
	status_panel.offset_right = -24
	status_panel.offset_top = -120
	status_panel.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.8)
	style.border_color = Color(0.2, 0.4, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	status_panel.add_theme_stylebox_override("panel", style)
	add_child(status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 4)
	status_panel.add_child(status_box)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.8))
	status_box.add_child(status_label)
	group_label = Label.new()
	group_label.add_theme_font_size_override("font_size", 15)
	group_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	status_box.add_child(group_label)
	version_label = Label.new()
	version_label.text = "v1.0 · Godot 4"
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
	status_box.add_child(version_label)
	_update_status()


func _update_status() -> void:
	if NetManager.is_online():
		status_label.text = Localization.t("status_online") + " · " + Localization.t("status_lan")
		status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.8))
	else:
		status_label.text = Localization.t("status_local")
		status_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	group_label.text = Localization.t("status_group_empty")


func _on_button(screen: String) -> void:
	AudioManager.ui_click()
	if screen == "quit":
		quit_requested.emit()
		return
	start_requested.emit(screen)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBLE_CHANGE and is_visible_in_tree():
		_update_status()


class Rain extends Control:
	var drops: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 46:
			drops.append({"x": randf() * 1920.0, "y": randf() * 1080.0, "s": randf_range(500.0, 900.0)})

	func _process(delta: float) -> void:
		for d in drops:
			d["y"] = float(d["y"]) + float(d["s"]) * delta
			d["x"] = float(d["x"]) - float(d["s"]) * delta * 0.12
			if float(d["y"]) > 1080.0:
				d["y"] = -20.0
				d["x"] = randf() * 1920.0
		queue_redraw()

	func _draw() -> void:
		for d in drops:
			draw_line(Vector2(float(d["x"]), float(d["y"])), Vector2(float(d["x"]) - 3.0, float(d["y"]) + 16.0),
				Color(0.6, 0.75, 0.9, 0.22), 1.0)
