extends Control
## Main menu: title, animated neon backdrop, the whole navigation tree
## (Solo / Modes / Loadout / Operatives / Online / Settings / Intel / Quit).
## One screen, panels swapped in the content area, all procedural.

var content: MarginContainer
var panel_root: VBoxContainer
var title_label: Label
var subtitle: Label
var glitch_timer := 0.0
var lan_discovery: LanDiscovery = null
var lan_label: Label = null
var lan_list_box: VBoxContainer = null
var current_screen := "home"
var mode_selected := "heist"
var mode_cards: Dictionary = {}
var tip_label: Label
var codename_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := NeonBackground.new()
	add_child(bg)
	var vignette := ColorRect.new()
	vignette.color = Color(0, 0, 0, 0)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# left rail
	var rail := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.009, 0.025, 0.93)
	sb.border_width_right = 1
	sb.border_color = Color(0.45, 0.15, 0.45, 0.55)
	rail.add_theme_stylebox_override("panel", sb)
	rail.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	rail.custom_minimum_size = Vector2(330, 0)
	add_child(rail)
	var rail_box := VBoxContainer.new()
	rail_box.add_theme_constant_override("separation", 8)
	rail.add_child(rail_box)
	rail_box.add_child(UiKit.vspace(26))
	var logo := UiKit.neon_title("ASH&LEAD", 40, UiKit.P["magenta"])
	rail_box.add_child(logo)
	var tag := UiKit.make_label("НЕОН-НУАР · КРИМИНАЛЬНЫЙ ТАКТИЧЕСКИЙ ШУТЕР", 10, UiKit.P["grey"])
	rail_box.add_child(tag)
	rail_box.add_child(UiKit.vspace(18))
	codename_label = UiKit.make_label("", 12, UiKit.P["cyan"])
	rail_box.add_child(codename_label)
	rail_box.add_child(UiKit.make_separator(Color(1, 1, 1, 0.07)))
	rail_box.add_child(UiKit.vspace(10))
	_add_rail_button(rail_box, "ИГРАТЬ", "home", UiKit.P["magenta"])
	_add_rail_button(rail_box, "РЕЖИМЫ", "modes", UiKit.P["cyan"])
	_add_rail_button(rail_box, "ONLINE", "online", UiKit.P["green"])
	_add_rail_button(rail_box, "ЭКИПИРОВКА", "loadout", UiKit.P["amber"])
	_add_rail_button(rail_box, "ОБЛИКИ", "outfits", UiKit.P["violet"])
	_add_rail_button(rail_box, "ДОСЬЕ", "intel", UiKit.P["ice"])
	_add_rail_button(rail_box, "НАСТРОЙКИ", "settings", UiKit.P["grey"])
	rail_box.add_child(UiKit.vspace(16))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_box.add_child(spacer)
	tip_label = UiKit.make_label("", 11, Color(0.6, 0.62, 0.72, 0.7))
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(290, 0)
	rail_box.add_child(tip_label)
	var quit := UiKit.make_small_button("ВЫЙТИ", UiKit.P["red"])
	quit.pressed.connect(func() -> void: get_tree().quit())
	rail_box.add_child(quit)
	rail_box.add_child(UiKit.vspace(16))

	# content area
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 380)
	content.add_theme_constant_override("margin_top", 70)
	content.add_theme_constant_override("margin_right", 70)
	content.add_theme_constant_override("margin_bottom", 50)
	add_child(content)
	panel_root = VBoxContainer.new()
	panel_root.add_theme_constant_override("separation", 12)
	content.add_child(panel_root)

	Sfx.play_music("menu")
	Sfx.start_ambience()
	GameFlow.set_screen("menu")
	codename_label.text = "АГЕНТ: %s  ·  УРОВЕНЬ %d  ·  %s" % [GameFlow.player_codename, int(GameFlow.profile.get("level", 1)), Util.fmt_cash(int(GameFlow.profile.get("cash", 0)))]
	tip_label.text = "СОВЕТ: " + GameFlow.random_tip()
	_show_home()
	_animate_in()


func _animate_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6)
	Ui.fade_from_black(0.8)


func _add_rail_button(parent: VBoxContainer, text: String, screen: String, accent: Color) -> void:
	var b := UiKit.make_button(text, accent, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var idx := screen
	b.pressed.connect(func() -> void: _navigate(idx))
	parent.add_child(b)


func _navigate(screen: String) -> void:
	current_screen = screen
	for c in panel_root.get_children():
		panel_root.remove_child(c)
		c.queue_free()
	match screen:
		"home":
			_show_home()
		"modes":
			_show_modes()
		"online":
			_show_online()
		"loadout":
			_show_loadout()
		"outfits":
			_show_outfits()
		"intel":
			_show_intel()
		"settings":
			_show_settings()


func _clear() -> void:
	for c in panel_root.get_children():
		panel_root.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------------------
# HOME
# ---------------------------------------------------------------------------

func _show_home() -> void:
	panel_root.add_child(UiKit.make_label("НЕОНОВЫЙ ГОРОД НЕ СПИТ. И НЕ ПРОЩАЕТ.", 13, UiKit.P["grey"]))
	var hero := UiKit.neon_title("ASH&LEAD", 92, UiKit.P["magenta"])
	hero.add_theme_color_override("font_shadow_color", Color(0.9, 0.1, 0.5, 0.35))
	panel_root.add_child(hero)
	var tag := UiKit.make_label("Криминальный шутер в неонуаре. Наёмники против правопорядка.\nОграбления, заложники, захват зданий, бомбы — и боты, которых можно вести за собой.", 15, Color(0.8, 0.8, 0.9, 0.85))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(760, 0)
	panel_root.add_child(tag)
	panel_root.add_child(UiKit.vspace(20))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	panel_root.add_child(grid)
	var play := _big_card("ИГРАТЬ", "Соло/боты. Полный матч с ИИ-напарниками, гражданскими и всеми режимами.", UiKit.P["magenta"], func() -> void:
		GameFlow.lobby_config["bots_fill"] = true
		GameFlow.start_solo(true))
	grid.add_child(play)
	var modes := _big_card("РЕЖИМЫ И КАРТЫ", "10 режимов: аркадные и полноценные. Карты генерируются заново.", UiKit.P["cyan"], func() -> void: _navigate("modes"))
	grid.add_child(modes)
	var online := _big_card("ONLINE", "Хост или подключение по LAN / реле. Боты добивают состав.", UiKit.P["green"], func() -> void: _navigate("online"))
	grid.add_child(online)
	var loadout := _big_card("ЭКИПИРОВКА", "Оружие, броня, гаджеты, перки. Стелс или мясорубка — на выбор.", UiKit.P["amber"], func() -> void: _navigate("loadout"))
	grid.add_child(loadout)
	panel_root.add_child(UiKit.vspace(16))
	var stats := UiKit.make_label("СЧЁТ: %d матчей · %d фрагов · %d хедшотов · %d ограблений" % [
		int(GameFlow.profile["stats"].get("matches", 0)),
		int(GameFlow.profile["stats"].get("kills", 0)),
		int(GameFlow.profile["stats"].get("headshots", 0)),
		int(GameFlow.profile["stats"].get("heists", 0)),
	], 13, UiKit.P["grey"])
	panel_root.add_child(stats)


func _big_card(title: String, desc: String, accent: Color, cb: Callable) -> Control:
	var b := UiKit.make_button("", accent, 20)
	b.custom_minimum_size = Vector2(0, 108)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.offset_left = 22
	v.offset_right = -22
	var l1 := UiKit.make_label(title, 22, accent)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l2 := UiKit.make_label(desc, 12, Color(0.8, 0.8, 0.9, 0.8))
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(300, 0)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	v.add_child(l2)
	b.add_child(v)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------------------
# MODES
# ---------------------------------------------------------------------------

func _show_modes() -> void:
	panel_root.add_child(UiKit.neon_title("РЕЖИМЫ", 44, UiKit.P["cyan"]))
	panel_root.add_child(UiKit.make_label("Аркадные — респаун, повторы, быстрая кровь. Полноценные — одна жизнь, деньги, полиция приезжает позже.", 13, UiKit.P["grey"]))
	panel_root.add_child(UiKit.vspace(8))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for mid in Db.MODE_ORDER:
		var m: Dictionary = Db.MODES[mid]
		grid.add_child(_mode_card(mid, m))
	panel_root.add_child(UiKit.vspace(6))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	panel_root.add_child(bottom)
	bottom.add_child(UiKit.make_label("КАРТА:", 14, UiKit.P["grey"]))
	var map_options := ["Случайная"] + _map_names()
	var map_opt := UiKit.make_option(map_options, 0)
	map_opt.item_selected.connect(func(i: int) -> void:
		GameFlow.lobby_config["map"] = "random" if i == 0 else Db.MAP_ORDER[i - 1])
	bottom.add_child(map_opt)
	bottom.add_child(UiKit.make_label("СЛОЖНОСТЬ БОТОВ:", 14, UiKit.P["grey"]))
	var diff_opt := UiKit.make_option(["Легко", "Нормально", "Сложно", "Кошмар"], GameFlow.bot_difficulty)
	diff_opt.item_selected.connect(func(i: int) -> void:
		GameFlow.bot_difficulty = i
		GameFlow.lobby_config["difficulty"] = i)
	bottom.add_child(diff_opt)
	bottom.add_child(UiKit.make_label("БОТОВ НА КОМАНДУ:", 14, UiKit.P["grey"]))
	var bots_opt := UiKit.make_option(["0", "1", "2", "3", "4", "5"], clampi(int(GameFlow.lobby_config.get("bot_count", 4)), 0, 5))
	bots_opt.item_selected.connect(func(i: int) -> void:
		GameFlow.lobby_config["bot_count"] = i
		GameFlow.lobby_config["bots_fill"] = i > 0)
	bottom.add_child(bots_opt)
	var start := UiKit.make_button("НАЧАТЬ МАТЧ", UiKit.P["magenta"], 18)
	start.custom_minimum_size = Vector2(260, 52)
	start.pressed.connect(_start_selected_mode)
	bottom.add_child(start)
	var start_host := UiKit.make_button("СОЗДАТЬ ЛОББИ", UiKit.P["green"], 16)
	start_host.custom_minimum_size = Vector2(220, 52)
	start_host.pressed.connect(func() -> void:
		GameFlow.lobby_config["mode"] = mode_selected
		GameFlow.start_host())
	bottom.add_child(start_host)


func _map_names() -> Array:
	var out: Array = []
	for id in Db.MAP_ORDER:
		out.append(str(Db.MAPS[id]["name"]))
	return out


func _mode_card(mid: String, m: Dictionary) -> Control:
	var accent := UiKit.P["magenta"] if str(m.get("family", "")) == "arcade" else UiKit.P["cyan"]
	var b := UiKit.make_button("", accent, 14)
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 3)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 8
	var tag := "АРКАДА · %s" % str(m.get("players", "5v5")) if str(m.get("family", "")) == "arcade" else "ОПЕРАЦИЯ · %s" % str(m.get("players", "5v5"))
	var l0 := UiKit.make_label(tag, 10, accent)
	l0.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l0)
	var l1 := UiKit.make_label(str(m.get("name", mid)), 17, Color.WHITE)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var l2 := UiKit.make_label(str(m.get("tagline", "")), 11, Color(0.85, 0.85, 0.95, 0.9))
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)
	var l3 := UiKit.make_label(str(m.get("brief", "")), 10, Color(0.7, 0.72, 0.8, 0.85))
	l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l3.custom_minimum_size = Vector2(260, 0)
	l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l3)
	b.add_child(v)
	b.pressed.connect(func() -> void:
		mode_selected = mid
		GameFlow.lobby_config["mode"] = mid
		_show_mode_detail(mid))
	return b


func _show_mode_detail(mid: String) -> void:
	_clear()
	var m: Dictionary = Db.MODES[mid]
	panel_root.add_child(UiKit.neon_title(str(m.get("name", mid)), 42, UiKit.P["magenta"]))
	panel_root.add_child(UiKit.make_label(str(m.get("tagline", "")), 18, UiKit.P["bone"]))
	panel_root.add_child(UiKit.vspace(8))
	var brief := UiKit.make_label(str(m.get("brief", "")), 15, Color(0.85, 0.85, 0.92, 0.9))
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(820, 0)
	panel_root.add_child(brief)
	panel_root.add_child(UiKit.vspace(12))
	panel_root.add_child(UiKit.make_label("ПРАВИЛА", 14, UiKit.P["cyan"]))
	for r in m.get("rules", []):
		panel_root.add_child(UiKit.make_label("▸ " + str(r), 14, UiKit.P["bone"]))
	panel_root.add_child(UiKit.vspace(12))
	var stats := UiKit.make_label("Команды: %s   ·   Гражданские: %d   ·   Полиция: %s   ·   Время: %s" % [
		str(m.get("players", "5v5")),
		int(m.get("civilians", 0)),
		("через %s" % Util.fmt_time(float(m.get("police_delay", 0.0)))) if float(m.get("police_delay", 0.0)) > 0.0 else "нет",
		("%d минут" % int(m.get("max_minutes", 0))) if int(m.get("max_minutes", 0)) > 0 else "до цели",
	], 13, UiKit.P["grey"])
	panel_root.add_child(stats)
	panel_root.add_child(UiKit.vspace(16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel_root.add_child(row)
	var back := UiKit.make_button("НАЗАД", UiKit.P["grey"], 16)
	back.custom_minimum_size = Vector2(180, 50)
	back.pressed.connect(func() -> void: _navigate("modes"))
	row.add_child(back)
	var start := UiKit.make_button("НАЧАТЬ", UiKit.P["magenta"], 18)
	start.custom_minimum_size = Vector2(280, 50)
	start.pressed.connect(func() -> void:
		GameFlow.lobby_config["mode"] = mid
		GameFlow.start_solo(true))
	row.add_child(start)


func _start_selected_mode() -> void:
	GameFlow.lobby_config["mode"] = mode_selected
	GameFlow.start_solo(true)


# ---------------------------------------------------------------------------
# ONLINE
# ---------------------------------------------------------------------------

func _show_online() -> void:
	panel_root.add_child(UiKit.neon_title("ONLINE", 44, UiKit.P["green"]))
	panel_root.add_child(UiKit.make_label("Один хост ведёт матч. Остальные подключаются и управляют своими бойцами.\nПустые слоты автоматически занимают боты той же команды.", 13, UiKit.P["grey"]))
	panel_root.add_child(UiKit.vspace(10))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	panel_root.add_child(cols)
	# host
	var host_panel := UiKit.make_panel()
	host_panel.custom_minimum_size = Vector2(420, 0)
	cols.add_child(host_panel)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	host_panel.add_child(hv)
	hv.add_child(UiKit.make_label("СОЗДАТЬ ИГРУ", 20, UiKit.P["green"]))
	hv.add_child(UiKit.make_label("Порт", 12, UiKit.P["grey"]))
	var port_edit := LineEdit.new()
	port_edit.text = "47800"
	hv.add_child(port_edit)
	hv.add_child(UiKit.make_label("Ник", 12, UiKit.P["grey"]))
	var name_edit := LineEdit.new()
	name_edit.text = GameFlow.player_codename
	hv.add_child(name_edit)
	var status := UiKit.make_label("", 12, UiKit.P["amber"])
	hv.add_child(status)
	var host_btn := UiKit.make_button("ХОСТ (LAN)", UiKit.P["green"], 16)
	host_btn.pressed.connect(func() -> void:
		NetLink.display_name = name_edit.text
		var err := NetLink.host_lan(int(port_edit.text))
		if err != "":
			status.text = err
		else:
			if lan_discovery == null:
				lan_discovery = LanDiscovery.new()
				add_child(lan_discovery)
			lan_discovery.start_broadcast({
				"host": NetLink.display_name, "port": int(port_edit.text),
				"mode": str(GameFlow.lobby_config.get("mode", "heist")),
				"map": str(GameFlow.lobby_config.get("map", "random")),
				"players": 1, "max": NetLink.max_players,
			})
			status.text = "Сервер поднят и виден в LAN."
			GameFlow.lobby_config["bots_fill"] = true
			GameFlow.set_screen("lobby")
			get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	hv.add_child(host_btn)
	var relay_btn := UiKit.make_button("ХОСТ (РЕЛЕ/WEB)", UiKit.P["cyan"], 14)
	relay_btn.pressed.connect(func() -> void:
		var err := NetLink.host_relay()
		if err != "":
			status.text = err
		else:
			NetLink.room_code = NetLink.make_room_code()
			status.text = "Реле на порту %d. Код комнаты: %s" % [NetLink.DEFAULT_RELAY_PORT, NetLink.room_code])
	hv.add_child(relay_btn)
	# join
	var join_panel := UiKit.make_panel()
	join_panel.custom_minimum_size = Vector2(420, 0)
	cols.add_child(join_panel)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 10)
	join_panel.add_child(jv)
	jv.add_child(UiKit.make_label("ПОДКЛЮЧИТЬСЯ", 20, UiKit.P["cyan"]))
	jv.add_child(UiKit.make_label("IP хоста", 12, UiKit.P["grey"]))
	var ip_edit := LineEdit.new()
	ip_edit.text = "127.0.0.1"
	jv.add_child(ip_edit)
	jv.add_child(UiKit.make_label("Порт", 12, UiKit.P["grey"]))
	var port_edit2 := LineEdit.new()
	port_edit2.text = "47800"
	jv.add_child(port_edit2)
	jv.add_child(UiKit.make_label("Код комнаты (для веб-реле)", 12, UiKit.P["grey"]))
	var code_edit := LineEdit.new()
	code_edit.placeholder_text = "ABCD-1234"
	jv.add_child(code_edit)
	var jstatus := UiKit.make_label("", 12, UiKit.P["amber"])
	jv.add_child(jstatus)
	var join_btn := UiKit.make_button("ПОДКЛЮЧИТЬСЯ (LAN)", UiKit.P["cyan"], 16)
	join_btn.pressed.connect(func() -> void:
		NetLink.display_name = name_edit.text
		var err := NetLink.join_lan(ip_edit.text.strip_edges(), int(port_edit2.text))
		jstatus.text = err if err != "" else "Подключаемся..."
		if err == "":
			GameFlow.set_screen("lobby")
			get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	jv.add_child(join_btn)
	var join_relay := UiKit.make_button("ПОДКЛЮЧИТЬСЯ (РЕЛЕ)", UiKit.P["violet"], 14)
	join_relay.pressed.connect(func() -> void:
		var err := NetLink.join_relay(NetLink.RELAY_URL, code_edit.text.strip_edges())
		jstatus.text = err if err != "" else "Реле: подключаемся..."
		if err == "":
			GameFlow.set_screen("lobby")
			get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	jv.add_child(join_relay)
	# LAN browser: hosts broadcast a UDP beacon, everyone else listens
	panel_root.add_child(UiKit.vspace(12))
	var disco_row := HBoxContainer.new()
	disco_row.add_theme_constant_override("separation", 10)
	panel_root.add_child(disco_row)
	var scan := UiKit.make_button("НАЙТИ СЕРВЕРЫ В LAN", UiKit.P["amber"], 14)
	disco_row.add_child(scan)
	var found_label := UiKit.make_label("Поиск не запущен", 12, UiKit.P["grey"])
	disco_row.add_child(found_label)
	lan_label = found_label
	var lan_list := VBoxContainer.new()
	lan_list.add_theme_constant_override("separation", 4)
	panel_root.add_child(lan_list)
	lan_list_box = lan_list
	scan.pressed.connect(func() -> void:
		if lan_discovery == null:
			lan_discovery = LanDiscovery.new()
			add_child(lan_discovery)
		lan_discovery.start_listen()
		found_label.text = "Слушаем порт %d..." % LanDiscovery.BEACON_PORT)
	var bots_note := UiKit.make_label("Сетевая игра в браузере работает через WebSocket-реле (tools/relay_server.js).\nНа десктопе доступен прямой ENet. В любом случае боты заменяют недостающих игроков и слушаются приказов.", 12, UiKit.P["grey"])
	bots_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bots_note.custom_minimum_size = Vector2(880, 0)
	panel_root.add_child(bots_note)


# ---------------------------------------------------------------------------
# LOADOUT
# ---------------------------------------------------------------------------

func _show_loadout() -> void:
	panel_root.add_child(UiKit.neon_title("ЭКИПИРОВКА", 40, UiKit.P["amber"]))
	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 10)
	panel_root.add_child(team_row)
	var team_label := UiKit.make_label("КОМАНДА: НАЁМНИКИ", 16, UiKit.P["magenta"])
	team_row.add_child(team_label)
	var switch := UiKit.make_small_button("ПЕРЕКЛЮЧИТЬ НА ПОЛИЦИЮ", UiKit.P["cyan"])
	var team_id := 0
	switch.pressed.connect(func() -> void:
		team_id = 1 - team_id
		team_label.text = "КОМАНДА: НАЁМНИКИ" if team_id == 0 else "КОМАНДА: ПРАВОПОРЯДОК"
		GameFlow.lobby_config["team"] = team_id
		_fill_loadout_slots(team_id))
	team_row.add_child(switch)
	panel_root.add_child(UiKit.vspace(6))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_root.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	v.name = "LoadoutBox"
	_fill_loadout_slots(0)


func _fill_loadout_slots(team_id: int) -> void:
	var box := panel_root.find_child("LoadoutBox", true, false)
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var key := "loadout_crim" if team_id == 0 else "loadout_police"
	var kit: Dictionary = GameFlow.profile.get(key, GameFlow.DEFAULT_LOADOUT["crim" if team_id == 0 else "police"])
	var rows := [["primary", "ОСНОВНОЕ", ["primary"]], ["secondary", "ПИСТОЛЕТ", ["secondary"]], ["melee", "БЛИЖНИЙ БОЙ", ["melee"]], ["gadget_a", "ГАДЖЕТ 1", ["gadget"]], ["gadget_b", "ГАДЖЕТ 2", ["gadget"]], ["armor", "БРОНЯ", ["armor"]], ["perk", "ПЕРК", ["perk"]]]
	for row_def in rows:
		var slot := str(row_def[0])
		var title := str(row_def[1])
		var kinds: Array = row_def[2]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		box.add_child(h)
		var l := UiKit.make_label(title, 14, UiKit.P["grey"])
		l.custom_minimum_size = Vector2(180, 0)
		h.add_child(l)
		var items: Array = []
		var ids: Array = []
		if slot == "armor":
			for aid in Db.ARMOR.keys():
				items.append("%s — %s" % [Db.ARMOR[aid]["name"], Db.ARMOR[aid]["desc"]])
				ids.append(aid)
		elif slot == "perk":
			# only perks bought in the buy menu can be slotted; the rest are shown
			# as locked so the player sees what the cash is for
			var owned_perks: Array = GameFlow.profile.get("perks", [])
			for pid in Db.PERKS.keys():
				var perk_id := str(pid)
				var perk_row := "%s — %s" % [Db.PERKS[pid]["name"], Db.PERKS[pid]["desc"]]
				if not owned_perks.has(perk_id):
					perk_row += "  [КУПИТЬ В МАТЧЕ]"
				items.append(perk_row)
				ids.append(perk_id)
		else:
			for wid in Db.WEAPON_ORDER:
				var w: Dictionary = Db.WEAPONS[wid]
				if not _slot_allows(slot, str(w.get("class", "")), str(w.get("kind", ""))):
					continue
				if team_id == 1 and not (1 in w.get("teams", [0, 1])):
					continue
				if team_id == 0 and not (0 in w.get("teams", [0, 1])):
					continue
				items.append(str(w.get("name", wid)))
				ids.append(wid)
		var opt := UiKit.make_option(items, maxi(0, ids.find(str(kit.get(slot, "")))))
		opt.custom_minimum_size = Vector2(620, 34)
		var s := slot
		var kk := key
		var ids_ref := ids.duplicate()
		opt.item_selected.connect(func(i: int) -> void:
			if i >= ids_ref.size():
				return
			var l2: Dictionary = GameFlow.profile.get(kk, {}).duplicate(true)
			l2[s] = ids_ref[i]
			GameFlow.profile[kk] = l2
			GameFlow.save_profile()
			Sfx.play_ui("ui_click"))
		h.add_child(opt)


func _slot_allows(slot: String, cls: String, kind: String) -> bool:
	match slot:
		"primary":
			return cls == "primary"
		"secondary":
			return cls == "secondary"
		"melee":
			return cls == "melee"
		"gadget_a", "gadget_b":
			return cls == "gadget"
	return false


# ---------------------------------------------------------------------------
# OUTFITS
# ---------------------------------------------------------------------------

func _show_outfits() -> void:
	panel_root.add_child(UiKit.neon_title("ОБЛИКИ", 40, UiKit.P["violet"]))
	panel_root.add_child(UiKit.make_label("Каждая миссия — своя экипировка. Выбери, кем ты войдёшь в здание.", 13, UiKit.P["grey"]))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for id in Db.CRIMINAL_OUTFITS.keys():
		grid.add_child(_outfit_card("crim", str(id), Db.CRIMINAL_OUTFITS[id]))
	for id in Db.POLICE_OUTFITS.keys():
		grid.add_child(_outfit_card("police", str(id), Db.POLICE_OUTFITS[id]))


func _outfit_card(team: String, id: String, data: Dictionary) -> Control:
	var accent := UiKit.P["magenta"] if team == "crim" else UiKit.P["cyan"]
	var p := UiKit.make_panel(Color(0.03, 0.025, 0.05, 0.9), Color(accent.r, accent.g, accent.b, 0.3))
	p.custom_minimum_size = Vector2(330, 190)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var preview := OutfitPreview.new()
	preview.setup(team, id, data)
	preview.custom_minimum_size = Vector2(300, 84)
	v.add_child(preview)
	v.add_child(UiKit.make_label(str(data.get("name", id)), 16, accent))
	var d := UiKit.make_label(str(data.get("desc", "")), 11, Color(0.75, 0.76, 0.84, 0.85))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	v.add_child(d)
	var btn := UiKit.make_small_button("ВЫБРАТЬ", accent)
	var is_current := str(GameFlow.profile.get("outfit_" + team, "")) == id
	if is_current:
		btn.text = "ВЫБРАНО"
	btn.pressed.connect(func() -> void:
		GameFlow.profile["outfit_" + team] = id
		GameFlow.save_profile()
		Sfx.play_ui("ui_buy")
		_signature_refresh())
	v.add_child(btn)
	return p


func _signature_refresh() -> void:
	Signals.notify.emit("Облик сохранён", "good")


# ---------------------------------------------------------------------------
# INTEL / CODEX
# ---------------------------------------------------------------------------

func _show_intel() -> void:
	panel_root.add_child(UiKit.neon_title("ДОСЬЕ", 40, UiKit.P["ice"]))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	panel_root.add_child(tabs)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", Color(0.82, 0.83, 0.9))
	panel_root.add_child(body)
	var sections := {
		"МЕХАНИКИ": _intel_mechanics(),
		"КАРТЫ": _intel_maps(),
		"ЛЮДИ": _intel_people(),
		"УПРАВЛЕНИЕ": _intel_controls(),
	}
	var keys := sections.keys()
	var buttons: Array[Button] = []
	for i in range(keys.size()):
		var b := UiKit.make_small_button(str(keys[i]), UiKit.P["cyan"])
		var k := str(keys[i])
		b.pressed.connect(func() -> void:
			body.text = str(sections[k])
			for bb in buttons:
				bb.modulate = Color(0.7, 0.7, 0.75)
			b.modulate = Color.WHITE)
		tabs.add_child(b)
		buttons.append(b)
	body.text = str(sections[keys[0]])


func _intel_mechanics() -> String:
	return """[color=#ff2bd6][b]СТЕЛС И ТУМАН ВОЙНЫ[/b][/color]
Ты видишь только то, что видит твоя команда. Геометрия запоминается навсегда, силуэты — нет. Враг в тени (0.0 света) замечает тебя с 200 px, в неоне — с 900 px. Бег даёт шум на 640 px, приседание — 70 px. Приседание + тень + неподвижность = почти невидимка, пока не выстрелишь.

[color=#35c9ff][b]СВЕТ И ТЕНЬ[/b][/color]
Каждая лампа — источник информации. Выстрел по лампе гасит сектор и создаёт укрытие. Фонарь делает из тебя мишень и слепит противника в конусе.

[color=#2bff9a][b]ШУМ[/b][/color]
Звук — это радиус: выстрел из АК — 1250 px, глушитель — 210 px, нож — 260 px, спринт — 640 px, дрель — 1500 px. ИИ расследует шум, гражданские паникуют и звонят в полицию.

[color=#ff1f4b][b]РАНЕНИЯ И ВСЕЛЕНИЕ[/b][/color]
Тяжёлое ранение (не в голову) с вероятностью 82% оставляет тебя в сознании на 34 секунды. Свой может поднять тебя (2.6 с). Если не подняли — вселение в бота команды (2 раза за матч, клавиша Q).

[color=#ffb02b][b]ПРИКАЗЫ БОТАМ[/b][/color]
C — колесо приказов: ВПЕРЁД / ОБХОД / ДЕРЖАТЬ / ОТСТУП. M + ЛКМ — приказ ближайшему боту (Shift — держать, Alt — обход). Боты идут, стреляют, укрываются, поднимают союзников и штурмуют по тем же правилам, что игроки.

[color=#ff2b62][b]ТРЕВОГА[/b][/color]
0 — тихо. 1 — подозрение (найден труп, сработала растяжка). 2 — тревога: копы выезжают, таймер сокращается до 60–150 с. В режимах-ограблениях полиция приезжает по времени ИЛИ по тревоге — что раньше.

[color=#8d2bff][b]ПОВТОРЫ[/b][/color]
В аркадных режимах буфер последних 5 секунд сохраняет каждое мультиубийство. После матча — лучший момент в slow-mo, прокрутка колёсиком, пауза по клику."""


func _intel_maps() -> String:
	var out := "[color=#ff2bd6][b]КАРТЫ ГЕНЕРИРУЮТСЯ ЗАНОВО[/b][/color]\nКаждый матч — новый план здания: комнаты, двери, окна, свет, мебель, гражданские и точки целей. Тема задаёт стиль, но не планировку.\n\n"
	for id in Db.MAP_ORDER:
		var m: Dictionary = Db.MAPS[id]
		out += "[color=#35c9ff][b]%s[/b][/color] — %s\n" % [m["name"], m["brief"]]
		out += "  [color=#7b7890]Палитра: %s · Акцент: %s · Охрана: %d%% · Гражданские: %s[/color]\n\n" % [
			" / ".join(m["palette"]), m["accent"], int(float(m["security"]) * 100.0),
			", ".join(m["civilians"]),
		]
	return out


func _intel_people() -> String:
	var out := "[color=#ff2bd6][b]НАЁМНИКИ (ASH)[/b][/color]\n"
	for id in Db.CRIMINAL_OUTFITS.keys():
		var o: Dictionary = Db.CRIMINAL_OUTFITS[id]
		out += "  [color=#ff2b62]%s[/color] — %s\n" % [o["name"], o["desc"]]
	out += "\n[color=#35c9ff][b]ПРАВОПОРЯДОК (LEAD)[/b][/color]\n"
	for id in Db.POLICE_OUTFITS.keys():
		var p: Dictionary = Db.POLICE_OUTFITS[id]
		out += "  [color=#35c9ff]%s[/color] — %s\n" % [p["name"], p["desc"]]
	out += "\n[color=#c8b98a][b]ГРАЖДАНСКИЕ[/b][/color]\n"
	for id in Db.CIVILIAN_ARCHETYPES.keys():
		var a: Dictionary = Db.CIVILIAN_ARCHETYPES[id]
		out += "  %s — поведение: %s\n" % [a["name"], ", ".join(a["behaviours"])]
	return out


func _intel_controls() -> String:
	return """[color=#ff2bd6][b]УПРАВЛЕНИЕ[/b][/color]
WASD — движение · Shift — спринт · Ctrl — присесть
ЛКМ — огонь · ПКМ — прицел · R — перезарядка · V — нож · X — сменить оружие
E — взаимодействие (двери, сейфы, заложники, заряд)
G — гаджет · B — арсенал · Q — вселение после смерти
C — колесо приказов · M — приказ по точке · Tab — табло
1–4 — слоты оружия · F — фонарь · Esc — пауза

[color=#35c9ff][b]СОВЕТЫ НОВИЧКУ[/b][/color]
— Один выстрел в голову дешевле, чем магазин в торс.
— Свет выдаёт. Тень прячет.
— Сумка с деньгами замедляет. Носи её в фургон, а не в бой.
— Если гражданский достал телефон — он уже вызвал копов.
— Полиция приезжает по таймеру. Не трать его на перестрелку."""


# ---------------------------------------------------------------------------
# SETTINGS
# ---------------------------------------------------------------------------

func _show_settings() -> void:
	panel_root.add_child(UiKit.neon_title("НАСТРОЙКИ", 40, UiKit.P["grey"]))
	var s: Dictionary = GameFlow.profile.get("settings", {})
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 10)
	panel_root.add_child(grid)
	_slider_row(grid, "ГЛАВНАЯ ГРОМКОСТЬ", "master", s)
	_slider_row(grid, "МУЗЫКА", "music", s)
	_slider_row(grid, "ЭФФЕКТЫ", "sfx", s)
	_slider_row(grid, "КРОВЬ", "blood", s)
	_slider_row(grid, "ТРЯСКА КАМЕРЫ", "shake", s)
	# graphics toggles: CRT, fog of war, bloom -- the three shader passes
	var vid: Dictionary = GameFlow.profile.get("video", {})
	var gfx := GridContainer.new()
	gfx.columns = 2
	gfx.add_theme_constant_override("h_separation", 30)
	gfx.add_theme_constant_override("v_separation", 8)
	panel_root.add_child(gfx)
	_check_row(gfx, "CRT / СКАНЛАЙНЫ", "crt", vid)
	_check_row(gfx, "ТУМАН ВОЙНЫ", "fog", vid)
	_check_row(gfx, "НЕОНОВОЕ СВЕЧЕНИЕ", "bloom", vid)
	panel_root.add_child(UiKit.vspace(16))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	panel_root.add_child(name_row)
	name_row.add_child(UiKit.make_label("ПОЗЫВНОЙ:", 14, UiKit.P["grey"]))
	var name_edit := LineEdit.new()
	name_edit.text = GameFlow.player_codename
	name_edit.custom_minimum_size = Vector2(320, 40)
	name_row.add_child(name_edit)
	var save := UiKit.make_button("СОХРАНИТЬ", UiKit.P["green"], 16)
	save.custom_minimum_size = Vector2(200, 44)
	save.pressed.connect(func() -> void:
		GameFlow.profile["name"] = name_edit.text.to_upper()
		GameFlow.player_codename = name_edit.text.to_upper()
		GameFlow.save_profile()
		Sfx.play_ui("ui_buy")
		Signals.notify.emit("Сохранено", "good"))
	name_row.add_child(save)
	panel_root.add_child(UiKit.vspace(20))
	var reset := UiKit.make_small_button("СБРОСИТЬ ПРОГРЕСС", UiKit.P["red"])
	reset.pressed.connect(func() -> void:
		GameFlow.reset_progress()
		Signals.notify.emit("Прогресс сброшен", "warning"))
	panel_root.add_child(reset)


func _check_row(grid: GridContainer, label: String, key: String, s: Dictionary) -> void:
	grid.add_child(UiKit.make_label(label, 14, UiKit.P["bone"]))
	var cb := CheckButton.new()
	cb.button_pressed = bool(s.get(key, true))
	cb.toggled.connect(func(v: bool) -> void:
		var vid: Dictionary = GameFlow.profile.get("video", {})
		vid[key] = v
		GameFlow.profile["video"] = vid
		GameFlow.save_profile()
		GameFlow.prefs_changed.emit("video"))
	grid.add_child(cb)


func _slider_row(grid: GridContainer, label: String, key: String, s: Dictionary) -> void:
	grid.add_child(UiKit.make_label(label, 14, UiKit.P["bone"]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	grid.add_child(row)
	var slider := UiKit.make_slider(float(s.get(key, 0.8)))
	var val := UiKit.make_label("%d%%" % int(float(s.get(key, 0.8)) * 100.0), 13, UiKit.P["cyan"])
	slider.value_changed.connect(func(v: float) -> void:
		val.text = "%d%%" % int(v * 100.0)
		var st: Dictionary = GameFlow.profile.get("settings", {})
		st[key] = v
		GameFlow.profile["settings"] = st
		GameFlow.apply_audio_settings()
		GameFlow.save_profile()
		GameFlow.prefs_changed.emit("audio"))
	row.add_child(slider)
	row.add_child(val)


func _process(delta: float) -> void:
	_refresh_lan_list()
	glitch_timer -= delta
	if glitch_timer <= 0.0:
		glitch_timer = randf_range(2.0, 6.0)


## Rebuild the discovered LAN server cards (called from _process, cheap).
func _refresh_lan_list() -> void:
	if lan_discovery == null or lan_list_box == null or not is_instance_valid(lan_list_box):
		return
	var seen := int(lan_list_box.get_meta("count", -1))
	if seen == lan_discovery.servers.size():
		return
	lan_list_box.set_meta("count", lan_discovery.servers.size())
	for c in lan_list_box.get_children():
		lan_list_box.remove_child(c)
		c.queue_free()
	if lan_discovery.servers.is_empty():
		if lan_label != null:
			lan_label.text = "Серверов не найдено (порт %d)" % LanDiscovery.BEACON_PORT
		return
	if lan_label != null:
		lan_label.text = "Найдено: %d" % lan_discovery.servers.size()
	for srv in lan_discovery.servers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := "%s:%d  ·  %s  ·  %s  ·  %d/%d" % [
			str(srv.get("ip", "?")), int(srv.get("port", 47800)),
			str(srv.get("host", "ХОСТ")), str(srv.get("mode", "—")),
			int(srv.get("players", 1)), int(srv.get("max", 12))]
		row.add_child(UiKit.make_label(text, 13, UiKit.P["bone"]))
		var join := UiKit.make_small_button("ПОДКЛЮЧИТЬСЯ", UiKit.P["green"])
		var ip := str(srv.get("ip", ""))
		var port := int(srv.get("port", 47800))
		join.pressed.connect(func() -> void:
			var err := NetLink.join_lan(ip, port)
			if err == "":
				GameFlow.set_screen("lobby")
				get_tree().change_scene_to_file("res://scenes/lobby.tscn")
			else:
				Signals.notify.emit(err, "bad"))
		row.add_child(join)
		lan_list_box.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if current_screen != "home":
				_navigate("home")
