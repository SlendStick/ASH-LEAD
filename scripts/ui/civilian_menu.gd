class_name CivilianMenu
extends Control
## Command menu for civilians: stay, follow, go to exit, calm down.

var hud: HUD
var match_ref: Match
var dim: ColorRect
var panel: PanelContainer
var title: Label
var requester: Character = null
var civilian: Character = null
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(960 - 220, 220)
	panel.custom_minimum_size = Vector2(440, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.07, 0.94)
	style.border_color = Color(0.25, 0.5, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title = Label.new()
	title.text = Localization.t("civilian_commands")
	title.add_theme_font_size_override("font_size", 23)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for entry in [
		{"cmd": "stay", "key": "civ_stay"},
		{"cmd": "follow", "key": "civ_follow"},
		{"cmd": "exit", "key": "civ_exit"},
		{"cmd": "calm", "key": "civ_calm"},
	]:
		var button := Button.new()
		button.text = Localization.t(entry["key"])
		button.add_theme_font_size_override("font_size", 18)
		button.alignment = Button.ALIGNMENT_LEFT
		button.pressed.connect(_on_command.bind(String(entry["cmd"])))
		box.add_child(button)


func open(character: Character, target: Character) -> void:
	requester = character
	civilian = target
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.ui_click()


func close() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hud != null and hud.match_ref != null and not hud.match_ref.finished:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func is_open() -> bool:
	return _open


func _on_command(cmd: String) -> void:
	if civilian != null and civilian.controller != null:
		civilian.controller.command(cmd, requester)
	close()
	AudioManager.ui_click()
