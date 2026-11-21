class_name LobbyScreen
extends Control
## Lobby: create/join a LAN game, teams, bots, mode/map/seed, rules, chat.

signal start_match_requested(config: Dictionary)
signal back_requested

var online: bool = false
var is_host: bool = false
var join_mode: bool = false
var ip_edit: LineEdit
var port_edit: LineEdit
var connect_button: Button
var selected_mode: String = "plant"
var selected_map: String = "clinic"
var room_code_label: Label
var player_rows: VBoxContainer
var chat_box: VBoxContainer
var chat_input: LineEdit
var mode_option: OptionButton
var map_option: OptionButton
var seed_label: Label
var team_size_option: OptionButton
var round_time_slider: HSlider
var police_delay_slider: HSlider
var civilians_check: CheckButton
var difficulty_option: OptionButton
var start_button: Button
var ready_button: Button
var password_edit: LineEdit
var connection_label: Label
var local_players: Array = []
var chat_messages: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_populate_modes()
	_populate_maps()
	if online:
		is_host = NetManager.is_host
		NetManager.peer_list_changed.connect(_refresh_players)
		NetManager.lobby_state_received.connect(_on_lobby_state)
		NetManager.chat_received.connect(_on_chat)
		NetManager.match_start_received.connect(_on_match_start)
		NetManager.connection_failed.connect(_on_connection_failed)
	else:
		_build_local_players()
	_refresh_players()
	_update_start_button()


func _background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/textures/bg_menu.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(0.5, 0.55, 0.65)
	add_child(bg)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.03, 0.86)
	add_child(dim)


func _build() -> void:
	_background()
	var title := _label(Localization.t("lobby_title"), 36)
	title.position = Vector2(50, 30)
	add_child(title)
	connection_label = _label("", 17)
	connection_label.position = Vector2(50, 78)
	add_child(connection_label)
	room_code_label = _label("", 18)
	room_code_label.position = Vector2(1600, 40)
	add_child(room_code_label)
	# LAN connect controls
	var connect_panel := PanelContainer.new()
	connect_panel.position = Vector2(1290, 20)
	connect_panel.custom_minimum_size = Vector2(580, 86)
	connect_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(connect_panel)
	var connect_box := HBoxContainer.new()
	connect_box.add_theme_constant_override("separation", 8)
	connect_panel.add_child(connect_box)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.0.10"
	ip_edit.custom_minimum_size = Vector2(190, 34)
	connect_box.add_child(ip_edit)
	port_edit = LineEdit.new()
	port_edit.text = "24565"
	port_edit.custom_minimum_size = Vector2(90, 34)
	connect_box.add_child(port_edit)
	connect_button = Button.new()
	connect_button.text = Localization.t("lobby_connect")
	connect_button.custom_minimum_size = Vector2(150, 40)
	connect_button.pressed.connect(_on_connect)
	connect_box.add_child(connect_button)
	var host_button := Button.new()
	host_button.text = Localization.t("lobby_host_here")
	host_button.custom_minimum_size = Vector2(150, 40)
	host_button.pressed.connect(_on_host_here)
	connect_box.add_child(host_button)
	var back := Button.new()
	back.text = Localization.t("back")
	back.position = Vector2(50, 1000)
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(_on_back)
	add_child(back)
	# Player list
	var players_panel := PanelContainer.new()
	players_panel.position = Vector2(50, 120)
	players_panel.custom_minimum_size = Vector2(620, 560)
	players_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(players_panel)
	var players_box := VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 4)
	players_panel.add_child(players_box)
	var players_title := _label(Localization.t("lobby_players"), 22)
	players_box.add_child(players_title)
	player_rows = VBoxContainer.new()
	player_rows.add_theme_constant_override("separation", 3)
	players_box.add_child(player_rows)
	var add_bot := Button.new()
	add_bot.text = Localization.t("lobby_add_bot")
	add_bot.custom_minimum_size = Vector2(160, 38)
	add_bot.pressed.connect(_on_add_bot)
	players_box.add_child(add_bot)
	# Settings
	var settings_panel := PanelContainer.new()
	settings_panel.position = Vector2(700, 120)
	settings_panel.custom_minimum_size = Vector2(560, 560)
	settings_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(settings_panel)
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 8)
	settings_panel.add_child(settings_box)
	settings_box.add_child(_label(Localization.t("lobby_settings"), 22))
	mode_option = OptionButton.new()
	for mode in Data.modes():
		mode_option.add_item(Localization.t("mode_" + String(mode.get("id", ""))))
	mode_option.item_selected.connect(_on_mode_selected)
	settings_box.add_child(_row(Localization.t("lobby_mode"), mode_option))
	map_option = OptionButton.new()
	for map_entry in Data.maps():
		map_option.add_item(Localization.t("map_" + String(map_entry.get("id", ""))))
	map_option.item_selected.connect(_on_map_selected)
	settings_box.add_child(_row(Localization.t("lobby_map"), map_option))
	seed_label = _label("", 18)
	settings_box.add_child(_row(Localization.t("lobby_seed"), seed_label))
	var reroll := Button.new()
	reroll.text = Localization.t("lobby_reroll")
	reroll.custom_minimum_size = Vector2(150, 36)
	reroll.pressed.connect(_on_reroll)
	settings_box.add_child(reroll)
	team_size_option = _make_option(["3", "4", "5", "6"], 2)
	settings_box.add_child(_row(Localization.t("lobby_team_size"), team_size_option))
	round_time_slider = _make_slider(60.0, 360.0, 30.0)
	settings_box.add_child(_row(Localization.t("lobby_round_time"), round_time_slider))
	police_delay_slider = _make_slider(20.0, 180.0, 5.0)
	settings_box.add_child(_row(Localization.t("lobby_police_delay"), police_delay_slider))
	civilians_check = CheckButton.new()
	civilians_check.text = Localization.t("lobby_civilians")
	civilians_check.button_pressed = true
	settings_box.add_child(civilians_check)
	difficulty_option = _make_option(["bot_easy", "bot_normal", "bot_hard"], 1)
	settings_box.add_child(_row(Localization.t("lobby_bot_difficulty"), difficulty_option))
	password_edit = LineEdit.new()
	password_edit.placeholder_text = Localization.t("lobby_password")
	password_edit.custom_minimum_size = Vector2(200, 34)
	settings_box.add_child(_row(Localization.t("lobby_password"), password_edit))
	# Chat
	var chat_panel := PanelContainer.new()
	chat_panel.position = Vector2(1290, 120)
	chat_panel.custom_minimum_size = Vector2(580, 420)
	chat_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(chat_panel)
	var chat_box_root := VBoxContainer.new()
	chat_box_root.add_theme_constant_override("separation", 4)
	chat_panel.add_child(chat_box_root)
	chat_box_root.add_child(_label(Localization.t("lobby_chat"), 21))
	chat_box = VBoxContainer.new()
	chat_box.add_theme_constant_override("separation", 2)
	chat_box_root.add_child(chat_box)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = Localization.t("lobby_chat_hint")
	chat_input.custom_minimum_size = Vector2(540, 36)
	chat_input.text_submitted.connect(_on_chat_submit)
	chat_box_root.add_child(chat_input)
	# Buttons
	ready_button = Button.new()
	ready_button.text = Localization.t("lobby_ready")
	ready_button.position = Vector2(1290, 570)
	ready_button.custom_minimum_size = Vector2(280, 56)
	ready_button.add_theme_font_size_override("font_size", 22)
	ready_button.pressed.connect(_on_ready)
	add_child(ready_button)
	start_button = Button.new()
	start_button.text = Localization.t("lobby_start")
	start_button.position = Vector2(1290, 640)
	start_button.custom_minimum_size = Vector2(280, 56)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(_on_start)
	add_child(start_button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.9)
	style.border_color = Color(0.2, 0.32, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.97))
	return label


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := _label(label_text, 17)
	label.custom_minimum_size = Vector2(200, 32)
	row.add_child(label)
	row.add_child(control)
	return row


func _make_option(items: Array, selected: int) -> OptionButton:
	var option := OptionButton.new()
	for item in items:
		option.add_item(Localization.t(item) if not item.is_valid_int() else item)
	option.selected = selected
	option.custom_minimum_size = Vector2(220, 34)
	return option


func _make_slider(min_value: float, max_value: float, step_val: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step_val
	slider.value = 120.0
	slider.custom_minimum_size = Vector2(220, 30)
	return slider


func _populate_modes() -> void:
	for i in Data.modes().size():
		if String(Data.modes()[i].get("id", "")) == selected_mode:
			mode_option.selected = i
			break


func _populate_maps() -> void:
	for i in Data.maps().size():
		if String(Data.maps()[i].get("id", "")) == selected_map:
			map_option.selected = i
			break
	_on_reroll()


# ---- players ---------------------------------------------------------------

func _build_local_players() -> void:
	local_players = [{
		"id": 1, "name": ProfileManager.player_name, "team": GameTypes.Team.CRIMINALS,
		"is_bot": false, "controlled": true, "ready": false,
		"loadout": Game.loadout if not Game.loadout.is_empty() else _default_loadout(GameTypes.Team.CRIMINALS),
		"role": Game.loadout.get("role", GameTypes.Role.OBSERVER),
	}]
	_refill_bots(local_players)


func _default_loadout(team: int) -> Dictionary:
	return {"primary": "kv14" if team == GameTypes.Team.POLICE else "vec9", "secondary": "p9", "gadget": "flash", "armor": 1, "medkits": 1}


func _refill_bots(players: Array) -> void:
	var team_size := int(team_size_option.get_item_text(team_size_option.selected).to_int()) if team_size_option != null else 5
	var difficulty := difficulty_option.selected if difficulty_option != null else 1
	for team in [GameTypes.Team.CRIMINALS, GameTypes.Team.POLICE]:
		var count := 0
		for p in players:
			if int(p["team"]) == team:
				count += 1
		while count < team_size:
			var id: int = 900 + int(team) * 100 + count
			var exists := false
			for p in players:
				if int(p["id"]) == id:
					exists = true
					break
			if exists:
				count += 1
				continue
			players.append({
				"id": id, "name": _bot_name(count) + "-" + str(team), "team": team,
				"is_bot": true, "controlled": false, "ready": true,
				"loadout": _default_loadout(team), "role": wrapi(count, 0, 6), "difficulty": difficulty,
			})
			count += 1


func _bot_name(index: int) -> String:
	var names := ["Ворон", "Кобра", "Тень", "Гром", "Лис", "Штык", "Маяк", "Ключ"]
	return names[index % names.size()]


func _refresh_players() -> void:
	if player_rows == null:
		return
	for child in player_rows.get_children():
		child.queue_free()
	var players := _players_source()
	for p in players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(String(p.get("name", "?")), 17)
		name_label.custom_minimum_size = Vector2(180, 26)
		row.add_child(name_label)
		var team_label := _label(GameTypes.team_name(int(p.get("team", 0))), 16)
		team_label.custom_minimum_size = Vector2(150, 26)
		team_label.modulate = Color(1.0, 0.55, 0.45) if int(p.get("team", 0)) == GameTypes.Team.CRIMINALS else Color(0.45, 0.8, 1.0)
		row.add_child(team_label)
		var kind := _label(Localization.t("lobby_bot") if bool(p.get("is_bot", false)) else Localization.t("lobby_human"), 15)
		kind.custom_minimum_size = Vector2(90, 26)
		kind.modulate = Color(0.6, 0.65, 0.7)
		row.add_child(kind)
		var ready := _label("●" if bool(p.get("ready", false)) else "○", 16)
		ready.modulate = Color(0.3, 0.95, 0.6) if bool(p.get("ready", false)) else Color(0.7, 0.4, 0.35)
		row.add_child(ready)
		player_rows.add_child(row)


func _players_source() -> Array:
	if online:
		var out: Array = []
		for id in NetManager.players:
			var p: Dictionary = NetManager.players[id]
			p["id"] = id
			out.append(p)
		return out
	return local_players


# ---- events ----------------------------------------------------------------

func _on_mode_selected(index: int) -> void:
	if index < 0 or index >= Data.modes().size():
		return
	selected_mode = String(Data.modes()[index].get("id", "plant"))
	AudioManager.ui_click()


func _on_map_selected(index: int) -> void:
	if index < 0 or index >= Data.maps().size():
		return
	selected_map = String(Data.maps()[index].get("id", "clinic"))
	_on_reroll()
	AudioManager.ui_click()


func _on_reroll() -> void:
	Game.map_seed = int(randi() % 1000000)
	seed_label.text = str(Game.map_seed)


func _on_add_bot() -> void:
	if online and not is_host:
		return
	AudioManager.ui_click()
	if online:
		NetManager.apply_bot_fill(int(team_size_option.get_item_text(team_size_option.selected).to_int()), true)
	else:
		var team := GameTypes.Team.CRIMINALS if randf() < 0.5 else GameTypes.Team.POLICE
		local_players.append({
			"id": 900 + team * 100 + local_players.size(), "name": _bot_name(local_players.size()), "team": team,
			"is_bot": true, "controlled": false, "ready": true,
			"loadout": _default_loadout(team), "role": GameTypes.Role.OBSERVER, "difficulty": difficulty_option.selected,
		})
		_refresh_players()


func _on_ready() -> void:
	AudioManager.ui_click()
	if online:
		var my_id := multiplayer.get_unique_id()
		var entry: Dictionary = NetManager.players.get(my_id, {})
		NetManager.set_ready(my_id, not bool(entry.get("ready", false)))
	else:
		var me: Dictionary = local_players[0]
		me["ready"] = not bool(me.get("ready", false))
		_refresh_players()
		_update_start_button()


func _on_start() -> void:
	AudioManager.ui_click()
	var config := get_config()
	if online:
		if not is_host:
			return
		NetManager.apply_bot_fill(int(team_size_option.get_item_text(team_size_option.selected).to_int()), true)
		NetManager.send_match_start(config)
	else:
		start_match_requested.emit(config)


func _on_back() -> void:
	AudioManager.ui_click()
	if online:
		NetManager.close_connection()
	back_requested.emit()


func _on_lobby_state(state: Dictionary) -> void:
	_online_sync()
	_refresh_players()
	_update_start_button()


func _on_connect() -> void:
	if online:
		return
	AudioManager.ui_click()
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		connection_label.text = Localization.t("lobby_address_required")
		return
	var port := int(port_edit.text.to_int()) if port_edit.text.is_valid_int() else NetManager.DEFAULT_PORT
	if NetManager.join_game(ip, port):
		online = true
		is_host = false
		join_mode = true
		connection_label.text = Localization.t("lobby_connecting")
		NetManager.connection_succeeded.connect(_on_connection_ok)
		NetManager.peer_list_changed.connect(_refresh_players)
		NetManager.lobby_state_received.connect(_on_lobby_state)
		NetManager.chat_received.connect(_on_chat)
		NetManager.match_start_received.connect(_on_match_start)


func _on_host_here() -> void:
	if online:
		return
	AudioManager.ui_click()
	var port := int(port_edit.text.to_int()) if port_edit.text.is_valid_int() else NetManager.DEFAULT_PORT
	if NetManager.host_game(port):
		online = true
		is_host = true
		join_mode = false
		NetManager.peer_list_changed.connect(_refresh_players)
		NetManager.lobby_state_received.connect(_on_lobby_state)
		NetManager.chat_received.connect(_on_chat)
		NetManager.match_start_received.connect(_on_match_start)
		_refresh_players()
		_update_start_button()


func _on_connection_ok() -> void:
	connection_label.text = Localization.t("status_online") + " · " + NetManager.room_code
	_refresh_players()
	_update_start_button()


func _on_connection_failed(_reason: String) -> void:
	connection_label.text = Localization.t("lobby_connection_failed")
	_update_start_button()


func _on_chat(sender_id: int, sender_name: String, text: String, team_only: bool) -> void:
	var prefix := ("[%s] " % Localization.t("chat_team")) if team_only else ""
	_add_chat_line(prefix + sender_name + ": " + text)


func _on_chat_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	chat_input.text = ""
	if online:
		NetManager.send_chat(text, false)
	else:
		_add_chat_line(ProfileManager.player_name + ": " + text)
		_add_chat_line(_bot_name(0) + ": " + Localization.t("chat_bot_reply"))


func _add_chat_line(text: String) -> void:
	chat_messages.append(text)
	if chat_messages.size() > 30:
		chat_messages.pop_front()
	if chat_box == null:
		return
	for child in chat_box.get_children():
		child.queue_free()
	for message in chat_messages:
		var label := _label(message, 15)
		label.autowrap = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(540, 0)
		chat_box.add_child(label)


func _online_sync() -> void:
	if not online:
		connection_label.text = Localization.t("status_local")
		return
	if NetManager.is_online():
		connection_label.text = Localization.t("status_online") + " · " + NetManager.room_code
		room_code_label.text = Localization.t("lobby_room_code") + ": " + NetManager.room_code
	else:
		connection_label.text = Localization.t("status_offline")


func _update_start_button() -> void:
	var can_start := not online or is_host
	start_button.visible = can_start
	ready_button.visible = online and not is_host


func get_config() -> Dictionary:
	var players := _players_source()
	var out_players: Array = []
	for p in players:
		out_players.append({
			"id": int(p.get("id", 0)),
			"name": String(p.get("name", "Operator")),
			"team": int(p.get("team", GameTypes.Team.CRIMINALS)),
			"is_bot": bool(p.get("is_bot", false)),
			"controlled": bool(p.get("controlled", false)) or (online and int(p.get("id", 0)) == multiplayer.get_unique_id()),
			"loadout": p.get("loadout", _default_loadout(int(p.get("team", 0)))),
			"role": int(p.get("role", GameTypes.Role.OBSERVER)),
			"difficulty": int(p.get("difficulty", difficulty_option.selected if difficulty_option != null else 1)),
		})
	return {
		"mode": selected_mode,
		"map": selected_map,
		"seed": Game.map_seed,
		"team_size": int(team_size_option.get_item_text(team_size_option.selected).to_int()) if team_size_option != null else 5,
		"players": out_players,
		"bot_difficulty": difficulty_option.selected if difficulty_option != null else 1,
		"round_time": round_time_slider.value,
		"rounds_to_win": int(Data.mode(selected_mode).get("rounds_to_win", 4)),
		"police_delay": police_delay_slider.value,
		"civilians": civilians_check.button_pressed,
		"civilian_count": 8,
		"password": password_edit.text,
	}


func _on_match_start(config: Dictionary) -> void:
	start_match_requested.emit(config)
