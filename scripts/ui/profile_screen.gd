class_name ProfileScreen
extends Control
## Profile and statistics: matches, wins, roles, civilians saved, history.

signal back_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.015, 0.025, 0.04, 0.97)
	add_child(bg)
	var title := _label(Localization.t("menu_profile"), 38)
	title.position = Vector2(60, 40)
	add_child(title)
	var back := Button.new()
	back.text = Localization.t("back")
	back.position = Vector2(60, 1000)
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(_on_back)
	add_child(back)
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 120)
	panel.custom_minimum_size = Vector2(1780, 820)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var p: Dictionary = ProfileManager.profile
	_add_line(box, "profile_name", ProfileManager.player_name)
	_add_line(box, "profile_matches", str(int(p.get("matches", 0))))
	_add_line(box, "profile_wins", str(int(p.get("wins", 0))))
	_add_line(box, "profile_losses", str(int(p.get("losses", 0))))
	_add_line(box, "profile_kills", str(int(p.get("kills", 0))))
	_add_line(box, "profile_deaths", str(int(p.get("deaths", 0))))
	_add_line(box, "profile_assists", str(int(p.get("assists", 0))))
	_add_line(box, "profile_civ_saved", str(int(p.get("civ_saved", 0))))
	_add_line(box, "profile_civ_hurt", str(int(p.get("civ_hurt", 0))))
	_add_line(box, "profile_objectives", str(int(p.get("objectives_done", 0))))
	_add_line(box, "profile_team_actions", str(int(p.get("team_actions", 0))))
	_add_line(box, "profile_favorite_role", GameTypes.role_name(_role_index(String(p.get("favorite_role", "")))))
	var history_title := _label(Localization.t("profile_history"), 22)
	box.add_child(history_title)
	var history: Array = p.get("history", [])
	if history.is_empty():
		box.add_child(_label(Localization.t("profile_no_history"), 17))
	for i in range(history.size() - 1, maxi(-1, history.size() - 21), -1):
		var entry: Dictionary = history[i]
		_add_line(box, "", "%s · %s · %s · %s" % [
			String(entry.get("date", "")), Localization.t("mode_" + String(entry.get("mode", ""))),
			String(entry.get("map", "")), String(entry.get("outcome", ""))], 16)


func _role_index(role_name: String) -> int:
	var names := ["observer", "technician", "medic", "support", "negotiator", "guardian"]
	for i in names.size():
		if names[i] == role_name:
			return i
	return 0


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.92)
	style.border_color = Color(0.2, 0.32, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.97))
	return label


func _add_line(box: VBoxContainer, key: String, value: String, size: int = 18) -> void:
	var label := _label((Localization.t(key) + ": " if not key.is_empty() else "") + value, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


func _on_back() -> void:
	AudioManager.ui_click()
	back_requested.emit()
