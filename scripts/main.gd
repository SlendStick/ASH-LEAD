extends Node
## Screen manager: menus, lobby, match, results, replays, pause.

var container: Control
var current: Control = null
var match_node: Match = null
var hud: HUD = null
var pause_menu: PauseMenu
var replay_view: ReplayView
var last_results: Dictionary = {}
var last_config: Dictionary = {}


func _ready() -> void:
	container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.settings_requested.connect(_on_pause_settings)
	pause_menu.leave_requested.connect(_on_leave_match)
	replay_view = ReplayView.new()
	add_child(replay_view)
	replay_view.closed.connect(_on_replay_closed)
	show_main_menu()


func _clear() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null


func goto(screen: Control) -> void:
	_clear()
	current = screen
	container.add_child(screen)


# ---- main menu -------------------------------------------------------------

func show_main_menu() -> void:
	_teardown_match()
	var menu := MainMenu.new()
	menu.start_requested.connect(_on_start_requested)
	menu.quit_requested.connect(_on_quit)
	goto(menu)


func _on_quit() -> void:
	AudioManager.ui_click()
	get_tree().quit()


func _on_start_requested(screen_name: String) -> void:
	match screen_name:
		"mode_select":
			show_lobby(false)
		"quick":
			start_quick_match()
		"lobby_create":
			show_lobby(false)
		"lobby_join":
			show_lobby(true)
		"training":
			start_training()
		"loadout":
			show_loadout_standalone()
		"profile":
			_show_backable(ProfileScreen.new())
		"collection":
			_show_backable(CollectionScreen.new())
		"settings":
			_show_backable(SettingsScreen.new())
		"credits":
			_show_backable(CreditsScreen.new())


func _show_backable(screen: Control) -> void:
	if screen.has_signal("back_requested"):
		screen.back_requested.connect(show_main_menu)
	goto(screen)


# ---- lobby -----------------------------------------------------------------

func show_lobby(join: bool) -> void:
	var lobby := LobbyScreen.new()
	lobby.join_mode = join
	lobby.start_match_requested.connect(start_match)
	lobby.back_requested.connect(show_main_menu)
	goto(lobby)


func show_loadout_standalone() -> void:
	var screen := LoadoutScreen.new()
	screen.setup(Game.current_mode, Game.current_map_id, GameTypes.Team.CRIMINALS)
	screen.confirmed.connect(func(loadout): Game.loadout = loadout)
	screen.back_requested.connect(show_main_menu)
	goto(screen)


# ---- match -----------------------------------------------------------------

func start_match(config: Dictionary) -> void:
	last_config = config.duplicate(true)
	_clear()
	hud = HUD.new()
	add_child(hud)
	match_node = Match.new()
	match_node.hud = hud
	add_child(match_node)
	match_node.match_finished.connect(_on_match_finished)
	match_node.pause_requested.connect(_on_pause_requested)
	match_node.death_screen_requested.connect(_on_death_screen)
	match_node.order_wheel_requested.connect(_on_order_wheel)
	match_node.scoreboard_requested.connect(_on_scoreboard)
	match_node.map_requested.connect(_on_map_overlay)
	hud.order_selected.connect(_on_order_selected)
	hud.spectate_requested.connect(_on_spectate)
	hud.take_control_requested.connect(_on_take_control)
	match_node.start_match(config)


func start_quick_match() -> void:
	var modes := ["plant", "heist", "hostage", "threshold", "archive", "tdm", "domination"]
	var maps := ["clinic", "warehouse", "college", "cinema", "mall", "archive"]
	var config := _offline_config(modes[randi() % modes.size()], maps[randi() % maps.size()], true)
	start_match(config)


func start_training() -> void:
	var config := _offline_config("tdm", "college", false)
	config["round_time"] = 600.0
	config["score_limit"] = 25
	start_match(config)


func _offline_config(mode: String, map_id: String, civilians: bool) -> Dictionary:
	var mode_data := Data.mode(mode)
	var loadout := Game.loadout if not Game.loadout.is_empty() else {
		"primary": "kv14", "secondary": "p9", "gadget": "flash", "armor": 1, "medkits": 1, "role": GameTypes.Role.OBSERVER,
	}
	var players: Array = [{
		"id": 1, "name": ProfileManager.player_name, "team": GameTypes.Team.CRIMINALS,
		"is_bot": false, "controlled": true, "loadout": loadout, "role": int(loadout.get("role", 0)),
	}]
	var team_size := int(mode_data.get("team_size", 5))
	for i in team_size - 1:
		players.append(_bot_entry(GameTypes.Team.CRIMINALS, i))
	for i in team_size:
		players.append(_bot_entry(GameTypes.Team.POLICE, i))
	return {
		"mode": mode,
		"map": map_id,
		"seed": int(randi() % 1000000),
		"team_size": team_size,
		"players": players,
		"bot_difficulty": 1,
		"round_time": float(mode_data.get("round_time", 120)),
		"rounds_to_win": int(mode_data.get("rounds_to_win", 4)),
		"police_delay": float(mode_data.get("police_delay", 60.0)),
		"civilians": civilians and bool(mode_data.get("civilians", true)),
		"civilian_count": 8,
	}


func _bot_entry(team: int, index: int) -> Dictionary:
	var names := ["Ворон", "Кобра", "Тень", "Гром", "Лис", "Штык", "Маяк", "Ключ"]
	var loadout := {
		"primary": "kv14" if team == GameTypes.Team.POLICE else "vec9",
		"secondary": "p9", "gadget": "flash", "armor": 1, "medkits": 1, "role": wrapi(index, 0, 6),
	}
	return {
		"id": 900 + team * 100 + index,
		"name": names[index % names.size()] + "-" + str(team),
		"team": team, "is_bot": true, "controlled": false,
		"loadout": loadout, "role": wrapi(index, 0, 6), "difficulty": 1,
	}


func _teardown_match() -> void:
	if match_node != null and is_instance_valid(match_node):
		match_node.queue_free()
	match_node = null
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if replay_view != null:
		replay_view.visible = false
	get_tree().paused = false


# ---- match signals ---------------------------------------------------------

func _on_match_finished(results: Dictionary) -> void:
	last_results = results
	if hud != null:
		hud.visible = false
	var screen := ResultsScreen.new()
	screen.setup(results)
	screen.restart_requested.connect(_on_restart)
	screen.change_mode_requested.connect(_on_change_mode)
	screen.lobby_requested.connect(_on_back_to_lobby)
	screen.menu_requested.connect(show_main_menu)
	screen.replay_requested.connect(_on_replay_requested)
	goto(screen)


func _on_restart() -> void:
	if last_config.is_empty():
		show_main_menu()
		return
	start_match(last_config)


func _on_change_mode() -> void:
	show_lobby(false)


func _on_back_to_lobby() -> void:
	if NetManager.is_online():
		show_lobby(false)
	else:
		show_main_menu()


func _on_pause_requested() -> void:
	if match_node == null:
		return
	if match_node.paused:
		pause_menu.open()
	else:
		pause_menu.close()


func _on_resume() -> void:
	if match_node != null:
		match_node.paused = false
		get_tree().paused = false
	pause_menu.close()


func _on_pause_settings() -> void:
	var screen := SettingsScreen.new()
	screen.back_requested.connect(_on_settings_back)
	goto(screen)


func _on_settings_back() -> void:
	# Return to the pause menu of the running match.
	if match_node != null and is_instance_valid(match_node):
		if current != null and is_instance_valid(current):
			current.queue_free()
		current = null
		if not pause_menu.is_open():
			pause_menu.open()
	else:
		show_main_menu()


func _on_leave_match() -> void:
	get_tree().paused = false
	show_main_menu()


func _on_death_screen(info: Dictionary) -> void:
	if hud != null:
		hud.show_death_screen(info)


func _on_order_wheel() -> void:
	if hud != null:
		hud.order_wheel.open()


func _on_order_selected(type: int) -> void:
	if match_node != null:
		match_node.handle_order_selected(type)


func _on_scoreboard() -> void:
	if hud != null:
		hud.scoreboard.toggle()


func _on_map_overlay() -> void:
	if hud != null:
		hud.map_overlay.toggle()


func _on_spectate(target: Character) -> void:
	if match_node != null:
		match_node.spectate_character(target)


func _on_take_control(bot: Character) -> void:
	if match_node != null:
		match_node.take_bot_control(bot)


func _on_replay_requested(highlight: Dictionary) -> void:
	if match_node == null or match_node.replay == null:
		return
	var t := float(highlight.get("t", 0.0))
	var frames := match_node.replay.get_frames_between(maxf(0.0, t - 4.0), t + 3.0)
	replay_view.open(highlight, frames)


func _on_replay_closed() -> void:
	if current != null and is_instance_valid(current) and current is ResultsScreen:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
