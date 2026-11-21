class_name ResultsScreen
extends Control
## Match results: outcome, reason, team and personal statistics, civilians,
## objectives and highlight replays.

signal restart_requested
signal change_mode_requested
signal lobby_requested
signal menu_requested
signal replay_requested(highlight: Dictionary)

var results: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(match_results: Dictionary) -> void:
	results = match_results
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.012, 0.02, 0.032, 0.97)
	add_child(bg)
	var outcome_key := String(results.get("outcome", "draw"))
	var outcome_text := Localization.t("results_win") if outcome_key == "win" else (Localization.t("results_loss") if outcome_key == "loss" else Localization.t("results_draw"))
	var title := _label(outcome_text, 62)
	title.position = Vector2(960 - 260, 50)
	title.custom_minimum_size = Vector2(520, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.4, 0.95, 0.8) if outcome_key == "win" else (Color(0.95, 0.35, 0.35) if outcome_key == "loss" else Color(0.85, 0.8, 0.5))
	add_child(title)
	var reason := _label(String(results.get("reason", "")), 21)
	reason.position = Vector2(960 - 320, 140)
	reason.custom_minimum_size = Vector2(640, 30)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(reason)
	var meta := _label("%s · %s · %s" % [
		Localization.t("mode_" + String(results.get("mode", ""))),
		String(results.get("map_name", "")),
		U.format_time(float(results.get("duration", 0.0)))], 17)
	meta.position = Vector2(960 - 320, 172)
	meta.custom_minimum_size = Vector2(640, 26)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.modulate = Color(0.6, 0.68, 0.75)
	add_child(meta)
	# Team scores
	var scores := _label("%s  %d : %d  %s" % [
		GameTypes.team_name(GameTypes.Team.CRIMINALS),
		int(results.get("team_criminals", 0)),
		int(results.get("team_police", 0)),
		GameTypes.team_name(GameTypes.Team.POLICE)], 30)
	scores.position = Vector2(960 - 240, 214)
	scores.custom_minimum_size = Vector2(480, 44)
	scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(scores)
	# Players table
	var table := PanelContainer.new()
	table.position = Vector2(180, 280)
	table.custom_minimum_size = Vector2(900, 600)
	table.add_theme_stylebox_override("panel", _panel_style())
	add_child(table)
	var table_box := VBoxContainer.new()
	table_box.add_theme_constant_override("separation", 4)
	table.add_child(table_box)
	var players: Array = results.get("players", [])
	if players.is_empty():
		table_box.add_child(_label(Localization.t("results_no_stats"), 18))
	for p in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.add_child(_cell(String(p.get("name", "")), 200))
		row.add_child(_cell(GameTypes.team_name(int(p.get("team", 0))), 130))
		row.add_child(_cell(GameTypes.role_name(int(p.get("role", 0))), 140))
		row.add_child(_cell(str(int(p.get("kills", 0))), 60))
		row.add_child(_cell(str(int(p.get("deaths", 0))), 60))
		row.add_child(_cell(str(int(p.get("objectives", 0))), 90))
		table_box.add_child(row)
	# Civilians
	var civ := _label("%s: %d    %s: %d" % [
		Localization.t("results_civ_saved"), int(results.get("civ_saved", 0)),
		Localization.t("results_civ_hurt"), int(results.get("civ_hurt", 0))], 18)
	civ.position = Vector2(180, 890)
	add_child(civ)
	# Highlights
	var highlights: Array = results.get("highlights", [])
	var hx := 1120
	var hy := 280
	if not highlights.is_empty():
		var htitle := _label(Localization.t("results_highlights"), 22)
		htitle.position = Vector2(hx, hy - 40)
		add_child(htitle)
		for i in highlights.size():
			var h: Dictionary = highlights[i]
			var button := Button.new()
			button.text = Localization.t(String(h.get("title_key", "highlight_last_kill")))
			button.custom_minimum_size = Vector2(360, 44)
			button.position = Vector2(hx, hy + i * 56)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_highlight.bind(h))
			add_child(button)
	else:
		var none := _label(Localization.t("results_no_highlights"), 18)
		none.position = Vector2(hx, hy)
		none.modulate = Color(0.6, 0.65, 0.7)
		add_child(none)
	# Buttons
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(960 - 380, 970)
	buttons.add_theme_constant_override("separation", 14)
	add_child(buttons)
	for entry in [
		{"signal": "restart_requested", "key": "results_restart"},
		{"signal": "change_mode_requested", "key": "results_change_mode"},
		{"signal": "lobby_requested", "key": "results_lobby"},
		{"signal": "menu_requested", "key": "results_menu"},
	]:
		var button := Button.new()
		button.text = Localization.t(entry["key"])
		button.custom_minimum_size = Vector2(180, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_on_button.bind(String(entry["signal"])))
		buttons.add_child(button)
	AudioManager.play_music("music_results")


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.92)
	style.border_color = Color(0.2, 0.32, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.97))
	return label


func _cell(text: String, width: int) -> Label:
	var label := _label(text, 17)
	label.custom_minimum_size = Vector2(width, 24)
	return label


func _on_highlight(highlight: Dictionary) -> void:
	AudioManager.ui_click()
	replay_requested.emit(highlight)


func _on_button(signal_name: String) -> void:
	AudioManager.ui_click()
	match signal_name:
		"restart_requested":
			restart_requested.emit()
		"change_mode_requested":
			change_mode_requested.emit()
		"lobby_requested":
			lobby_requested.emit()
		"menu_requested":
			menu_requested.emit()
