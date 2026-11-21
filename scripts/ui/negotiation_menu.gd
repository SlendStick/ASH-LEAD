class_name NegotiationMenu
extends Control
## Negotiation lines for the hostage mode. Abstract game effects only.

var hud: HUD
var match_ref: Match
var dim: ColorRect
var panel: PanelContainer
var title: Label
var status: Label
var requester: Character = null
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(960 - 280, 200)
	panel.custom_minimum_size = Vector2(560, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.07, 0.95)
	style.border_color = Color(0.5, 0.35, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title = Label.new()
	title.text = Localization.t("negotiation_title")
	title.add_theme_font_size_override("font_size", 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	status = Label.new()
	status.text = Localization.t("negotiation_hint")
	status.add_theme_font_size_override("font_size", 16)
	status.autowrap = TextServer.AUTOWRAP_WORD_SMART
	status.modulate = Color(0.8, 0.85, 0.9)
	box.add_child(status)
	for entry in [
		{"line": "calm", "key": "neg_calm", "desc": "neg_calm_desc"},
		{"line": "demand", "key": "neg_demand", "desc": "neg_demand_desc"},
		{"line": "threat", "key": "neg_threat", "desc": "neg_threat_desc"},
	]:
		var button := Button.new()
		button.text = Localization.t(entry["key"]) + " — " + Localization.t(entry["desc"])
		button.add_theme_font_size_override("font_size", 17)
		button.alignment = Button.ALIGNMENT_LEFT
		button.pressed.connect(_on_line.bind(String(entry["line"])))
		box.add_child(button)


func open(character: Character) -> void:
	requester = character
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


func _on_line(line: String) -> void:
	if match_ref != null and match_ref.mode != null and match_ref.mode.has_method("negotiate"):
		match_ref.mode.negotiate(line)
		status.text = Localization.t("feed_neg_" + line)
	AudioManager.play("radio_blip", Vector2.INF, -8.0)
