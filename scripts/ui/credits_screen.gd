class_name CreditsScreen
extends Control
## Credits / titrys.

signal back_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.012, 0.02, 0.032, 0.98)
	add_child(bg)
	var title := _label("ASH&LEAD", 64)
	title.position = Vector2(960 - 200, 120)
	title.custom_minimum_size = Vector2(400, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var box := VBoxContainer.new()
	box.position = Vector2(960 - 400, 260)
	box.custom_minimum_size = Vector2(800, 600)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for line in [
		"credits_concept",
		"credits_design",
		"credits_code",
		"credits_art",
		"credits_audio",
		"credits_localisation",
		"credits_thanks",
	]:
		var label := _label(Localization.t(line), 19)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.75, 0.82, 0.9)
		box.add_child(label)
	var back := Button.new()
	back.text = Localization.t("back")
	back.position = Vector2(960 - 80, 920)
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(_on_back)
	add_child(back)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	return label


func _on_back() -> void:
	AudioManager.ui_click()
	back_requested.emit()
