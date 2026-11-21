class_name MapOverlay
extends Control
## Full tactical map (M): bigger fog-of-war map with markers.

var hud: HUD
var match_ref: Match
var dim: ColorRect
var map: Minimap
var title: Label
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(dim)
	title = Label.new()
	title.text = Localization.t("map_title")
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(960 - 90, 40)
	add_child(title)
	map = load("res://scripts/ui/minimap.gd").new()
	map.position = Vector2(960 - 420, 110)
	map.custom_minimum_size = Vector2(840, 640)
	add_child(map)


func _process(_delta: float) -> void:
	if _open:
		map.queue_redraw()


func open() -> void:
	_open = true
	visible = true
	map.match_ref = match_ref
	AudioManager.ui_click()


func close() -> void:
	_open = false
	visible = false


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func is_open() -> bool:
	return _open
