class_name Scoreboard
extends Control
## Player table (Tab): teams, kills, deaths, objectives, ping.

var hud: HUD
var match_ref: Match
var panel: PanelContainer
var rows: VBoxContainer
var title: Label
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(960 - 380, 120)
	panel.custom_minimum_size = Vector2(760, 720)
	panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	style.bg_color = Color(0.03, 0.045, 0.07, 0.92)
	style.border_color = Color(0.2, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title = Label.new()
	title.text = Localization.t("scoreboard_title")
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	box.add_child(rows)


func open() -> void:
	_open = true
	visible = true
	_rebuild()
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


func _rebuild() -> void:
	if rows == null or match_ref == null:
		return
	for child in rows.get_children():
		child.queue_free()
	_add_team_header(GameTypes.Team.CRIMINALS)
	_add_rows_for(GameTypes.Team.CRIMINALS)
	_add_team_header(GameTypes.Team.POLICE)
	_add_rows_for(GameTypes.Team.POLICE)


func _add_team_header(team: int) -> void:
	var label := Label.new()
	label.text = GameTypes.team_name(team) + "  —  " + str(match_ref.mode.get_score(team))
	label.add_theme_font_size_override("font_size", 21)
	label.modulate = Color(0.4, 0.8, 1.0) if team == GameTypes.Team.POLICE else Color(1.0, 0.5, 0.4)
	rows.add_child(label)


func _add_rows_for(team: int) -> void:
	for c in match_ref.characters:
		if c.team != team or c.team == GameTypes.Team.CIVILIAN:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.add_child(_cell(c.char_name, 240))
		row.add_child(_cell(GameTypes.role_name(c.role), 150))
		row.add_child(_cell(str(_kills(c)), 70))
		row.add_child(_cell(str(_deaths(c)), 70))
		row.add_child(_cell(str(_objectives(c)), 90))
		row.add_child(_cell(_ping_text(c), 80))
		rows.add_child(row)


func _cell(text: String, width: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 22)
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color(0.85, 0.9, 0.95)
	return label


func _kills(c: Character) -> int:
	return int(match_ref.stats.get(str(c.player_id), {}).get("kills", 0))


func _deaths(c: Character) -> int:
	return int(match_ref.stats.get(str(c.player_id), {}).get("deaths", 0))


func _objectives(c: Character) -> int:
	return int(match_ref.stats.get(str(c.player_id), {}).get("objectives", 0))


func _ping_text(c: Character) -> String:
	if not NetManager.is_online():
		return "—"
	if c.player_id == 0:
		return "—"
	var entry: Dictionary = NetManager.players.get(c.player_id, {})
	return str(int(entry.get("ping", 0))) + " мс"
