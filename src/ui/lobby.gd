extends Control
## LAN / relay lobby: shows both teams, lets you pick a side, ready up, and has
## the host start the match. Empty slots are filled with bots of the matching
## difficulty so a 2-player game still feels like a war.

var root: VBoxContainer
var teams_box: HBoxContainer
var status: Label
var start_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.012, 0.03, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	root.add_child(UiKit.neon_title("ЛОББИ", 44, UiKit.P["green"]))
	root.add_child(UiKit.make_label("Выбери сторону. Пустые места займут боты.", 14, UiKit.P["grey"]))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	root.add_child(modes)
	modes.add_child(UiKit.make_label("РЕЖИМ:", 14, UiKit.P["grey"]))
	var m_names: Array = []
	for id in Db.MODE_ORDER:
		m_names.append(str(Db.MODES[id]["name"]))
	var cur_mode := str(GameFlow.lobby_config.get("mode", "heist"))
	var sel := maxi(0, Db.MODE_ORDER.find(cur_mode))
	var opt := UiKit.make_option(m_names, sel)
	opt.item_selected.connect(func(i: int) -> void: GameFlow.lobby_config["mode"] = Db.MODE_ORDER[i])
	modes.add_child(opt)
	var map_names: Array = ["Случайная"]
	for id in Db.MAP_ORDER:
		map_names.append(str(Db.MAPS[id]["name"]))
	var mopt := UiKit.make_option(map_names, 0)
	mopt.item_selected.connect(func(i: int) -> void: GameFlow.lobby_config["map"] = "random" if i == 0 else Db.MAP_ORDER[i - 1])
	modes.add_child(mopt)
	teams_box = HBoxContainer.new()
	teams_box.add_theme_constant_override("separation", 24)
	teams_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(teams_box)
	status = UiKit.make_label("", 13, UiKit.P["amber"])
	root.add_child(status)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	var back := UiKit.make_button("НАЗАД", UiKit.P["grey"], 16)
	back.custom_minimum_size = Vector2(180, 48)
	back.pressed.connect(func() -> void:
		NetLink.disconnect_all()
		GameFlow.back_to_menu())
	bottom.add_child(back)
	var cmd := UiKit.make_button("КОМАНДНЫЕ ПРИКАЗЫ", UiKit.P["cyan"], 16)
	cmd.custom_minimum_size = Vector2(260, 48)
	cmd.pressed.connect(func() -> void: Signals.notify.emit("В бою: C — колесо приказов, M — приказ по точке", "info"))
	bottom.add_child(cmd)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	start_btn = UiKit.make_button("НАЧАТЬ", UiKit.P["magenta"], 18)
	start_btn.custom_minimum_size = Vector2(280, 48)
	start_btn.pressed.connect(func() -> void:
		GameFlow.lobby_config["mode"] = str(GameFlow.lobby_config.get("mode", "heist"))
		GameFlow.start_host())
	bottom.add_child(start_btn)
	_refresh()
	NetLink.lobby_updated.connect(func(_l: Array) -> void: _refresh())
	NetLink.connection_failed.connect(func(reason: String) -> void: status.text = reason)
	Sfx.play_music("menu")


func _refresh() -> void:
	for c in teams_box.get_children():
		teams_box.remove_child(c)
		c.queue_free()
	var counts := {0: 0, 1: 0}
	for m in NetLink.lobby:
		counts[int(m.get("team", 0))] += 1
	teams_box.add_child(_team_column("НАЁМНИКИ", Db.TEAM_CRIMINAL, UiKit.P["magenta"], counts[0]))
	teams_box.add_child(_team_column("ПРАВОПОРЯДОК", Db.TEAM_POLICE, UiKit.P["cyan"], counts[1]))
	status.text = "Подключено: %d · Транспорт: %s · Пустые слоты займут боты" % [NetLink.lobby.size(), NetLink.transport]
	start_btn.visible = NetLink.is_host


func _team_column(title: String, team: int, accent: Color, count: int) -> Control:
	var p := UiKit.make_panel(Color(0.03, 0.025, 0.05, 0.9), Color(accent.r, accent.g, accent.b, 0.4))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiKit.make_label("%s (%d)" % [title, count], 20, accent))
	for m in NetLink.lobby:
		if int(m.get("team", 0)) != team:
			continue
		var l := UiKit.make_label("◆ %s%s" % [str(m.get("name", "?")), "  [ХОСТ]" if bool(m.get("is_host", false)) else ""], 15, UiKit.P["bone"])
		v.add_child(l)
	var join := UiKit.make_button("ВСТАТЬ В СТРОЙ", accent, 14)
	join.custom_minimum_size = Vector2(0, 38)
	join.pressed.connect(func() -> void:
		NetLink.set_my_team(team)
		GameFlow.lobby_config["team"] = team)
	v.add_child(join)
	return p
