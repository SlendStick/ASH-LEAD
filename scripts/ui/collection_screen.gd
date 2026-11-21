class_name CollectionScreen
extends Control
## Cosmetic collection: original silhouettes and colour variants per side.
## Purely cosmetic - never hides team affiliation.

signal back_requested

const SKINS := [
	{"id": "default", "name": "Стандарт", "desc": "Базовый комплект."},
	{"id": "rain", "name": "Дождь", "desc": "Тёмный плащ и капюшон."},
	{"id": "neon", "name": "Неон", "desc": "Кислотные акценты на экипировке."},
	{"id": "ghost", "name": "Призрак", "desc": "Облегчённый комплект без ярких меток."},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.015, 0.025, 0.04, 0.97)
	add_child(bg)
	var title := _label(Localization.t("menu_collection"), 38)
	title.position = Vector2(60, 40)
	add_child(title)
	var back := Button.new()
	back.text = Localization.t("back")
	back.position = Vector2(60, 1000)
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(_on_back)
	add_child(back)
	var hint := _label(Localization.t("collection_hint"), 17)
	hint.position = Vector2(60, 100)
	hint.modulate = Color(0.6, 0.75, 0.8)
	add_child(hint)
	var grid := GridContainer.new()
	grid.position = Vector2(80, 160)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	add_child(grid)
	for skin in SKINS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(840, 260)
		var style := StyleBoxFlat.new()
		var unlocked: bool = skin["id"] == "default" or String(skin["id"]) in ProfileManager.profile.get("unlocked_skins", ["default"])
		style.bg_color = Color(0.03, 0.045, 0.07, 0.9) if unlocked else Color(0.03, 0.035, 0.045, 0.7)
		style.border_color = Color(0.25, 0.5, 0.45) if unlocked else Color(0.2, 0.22, 0.26)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", style)
		grid.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		box.add_child(_label(Localization.t("skin_" + String(skin["id"])), 24))
		box.add_child(_label(Localization.t("skin_" + String(skin["id"]) + "_desc"), 16))
		var status := _label(Localization.t("skin_unlocked") if unlocked else Localization.t("skin_locked"), 16)
		status.modulate = Color(0.4, 0.9, 0.7) if unlocked else Color(0.7, 0.5, 0.4)
		box.add_child(status)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.97))
	return label


func _on_back() -> void:
	AudioManager.ui_click()
	back_requested.emit()
