extends CanvasLayer
## In-match HUD. Everything the player needs in one glance:
##   * top bar: mode, clock, team scores, objective banner, alarm / police ETA
##   * bottom left: vitals (HP / armour / stamina), bleed, downed state
##   * bottom right: weapon card, ammo, gadget charges, loadout slots
##   * top right: minimap + killfeed
##   * centre: crosshair, interaction prompts, damage numbers
##   * overlays: scoreboard, buy menu, command wheel, pause, end screen, replay
## All drawn with Controls + a few custom `_draw` widgets; no textures needed.

var world: Node
var root: Control
var crosshair: Crosshair
var damage_flash: Node
var minimap: Minimap
var top_bar: HBoxContainer
var net_label: Label
var objective_label: Label
var score_label: Label
var timer_label: Label
var alarm_label: Label
var hp_bar: ProgressBar
var armor_bar: ProgressBar
var stamina_bar: ProgressBar
var hp_label: Label
var weapon_card: VBoxContainer
var ammo_label: Label
var mode_label: Label
var gadget_label: Label
var killfeed_box: VBoxContainer
var event_log: VBoxContainer
var interact_label: Label
var interact_bar: ProgressBar
var scoreboard: PanelContainer
var scoreboard_rows: VBoxContainer
var command_wheel: Control
var buy_panel: PanelContainer
var pause_panel: PanelContainer
var end_panel: PanelContainer
var replay_panel: PanelContainer
var possession_panel: PanelContainer
var possession_buttons: VBoxContainer
var t := 0.0
var scoreboard_visible := false
var command_open := false
var paused := false
var end_shown := false
var event_timer := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top()
	_build_vitals()
	_build_weapon()
	_build_killfeed()
	_build_interact()
	_build_overlays()
	crosshair = Crosshair.new()
	crosshair.world = world
	root.add_child(crosshair)
	damage_flash = DamageFlash.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)
	root.move_child(damage_flash, 0)
	Signals.match_event.connect(_on_event)
	Signals.objective_changed.connect(_on_objective)
	Signals.killfeed.connect(_on_killfeed)
	Signals.alarm_changed.connect(_on_alarm)
	Signals.match_ended.connect(show_end)
	Signals.interact_prompt.connect(_on_prompt)
	Signals.score_changed.connect(_on_score)
	Signals.replay_ready.connect(_on_replay)


func _build_top() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.015, 0.035, 0.82)
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.2, 0.5, 0.4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_child(panel)
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 22)
	panel.add_child(top_bar)
	mode_label = UiKit.make_label("РЕЖИМ", 15, UiKit.P["magenta"])
	top_bar.add_child(mode_label)
	score_label = UiKit.make_label("0 : 0", 22, UiKit.P["bone"])
	top_bar.add_child(score_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	timer_label = UiKit.make_label("0:00", 20, UiKit.P["ice"])
	top_bar.add_child(timer_label)
	var s2 := Control.new()
	s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(s2)
	alarm_label = UiKit.make_label("ТИХО", 15, UiKit.P["amber"])
	top_bar.add_child(alarm_label)
	net_label = UiKit.make_label("", 12, UiKit.P["grey"])
	top_bar.add_child(net_label)
	objective_label = UiKit.make_label("", 14, UiKit.P["cyan"])
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-300, 54)
	objective_label.custom_minimum_size = Vector2(600, 0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(objective_label)


func _build_vitals() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(26, -128)
	box.custom_minimum_size = Vector2(270, 0)
	box.add_theme_constant_override("separation", 5)
	root.add_child(box)
	hp_label = UiKit.make_label("100", 26, UiKit.P["bone"])
	box.add_child(hp_label)
	hp_bar = UiKit.make_bar(Color("ff1f4b"))
	box.add_child(hp_bar)
	armor_bar = UiKit.make_bar(Color("35c9ff"), Color(0.05, 0.08, 0.1, 0.9), 6)
	box.add_child(armor_bar)
	stamina_bar = UiKit.make_bar(Color("b6ff2b"), Color(0.05, 0.08, 0.05, 0.9), 4)
	box.add_child(stamina_bar)
	var hint := UiKit.make_label("E Взаимод.  B Магазин  Q Вселение  C Приказы  Tab Счёт", 11, Color(0.65, 0.65, 0.75, 0.7))
	box.add_child(hint)


func _build_weapon() -> void:
	weapon_card = VBoxContainer.new()
	weapon_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_card.position = Vector2(-300, -132)
	weapon_card.custom_minimum_size = Vector2(272, 0)
	weapon_card.add_theme_constant_override("separation", 4)
	root.add_child(weapon_card)
	var name_l := UiKit.make_label("ОРУЖИЕ", 18, UiKit.P["cyan"])
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_card.add_child(name_l)
	name_l.name = "WeaponName"
	ammo_label = UiKit.make_label("30 / 120", 32, UiKit.P["bone"])
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_card.add_child(ammo_label)
	gadget_label = UiKit.make_label("", 13, UiKit.P["grey"])
	gadget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_card.add_child(gadget_label)


func _build_killfeed() -> void:
	killfeed_box = VBoxContainer.new()
	killfeed_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	killfeed_box.position = Vector2(-360, 58)
	killfeed_box.custom_minimum_size = Vector2(336, 0)
	killfeed_box.alignment = BoxContainer.ALIGNMENT_END
	killfeed_box.add_theme_constant_override("separation", 4)
	root.add_child(killfeed_box)
	event_log = VBoxContainer.new()
	event_log.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	event_log.position = Vector2(-320, 96)
	event_log.custom_minimum_size = Vector2(640, 0)
	event_log.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(event_log)
	minimap = Minimap.new()
	minimap.world = world
	minimap.map = world.get("map")
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-236, 250)
	minimap.custom_minimum_size = Vector2(210, 150)
	root.add_child(minimap)


func _build_interact() -> void:
	interact_label = UiKit.make_label("", 17, UiKit.P["bone"])
	interact_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	interact_label.position = Vector2(-220, 70)
	interact_label.custom_minimum_size = Vector2(440, 0)
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(interact_label)
	interact_bar = UiKit.make_bar(Color("2bff9a"), Color(0.05, 0.08, 0.06, 0.9), 6)
	interact_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	interact_bar.position = Vector2(-110, 96)
	interact_bar.custom_minimum_size = Vector2(220, 6)
	root.add_child(interact_bar)


func _build_overlays() -> void:
	# scoreboard
	scoreboard = PanelContainer.new()
	scoreboard.add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.02, 0.015, 0.04, 0.94), Color(0.4, 0.2, 0.55, 0.6), 1, 4))
	scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scoreboard.custom_minimum_size = Vector2(760, 420)
	scoreboard.position = Vector2(-380, -210)
	root.add_child(scoreboard)
	scoreboard_rows = VBoxContainer.new()
	scoreboard_rows.add_theme_constant_override("separation", 3)
	scoreboard.add_child(scoreboard_rows)
	scoreboard.visible = false
	# command wheel
	command_wheel = load("res://src/ui/command_wheel.gd").new()
	command_wheel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	command_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(command_wheel)
	command_wheel.visible = false
	# buy panel
	buy_panel = load("res://src/ui/buy_menu.gd").new()
	buy_panel.set("world", world)
	buy_panel.visible = false
	root.add_child(buy_panel)
	# pause
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.02, 0.015, 0.04, 0.96), Color(0.4, 0.2, 0.55, 0.6), 1, 4))
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-220, -180)
	pause_panel.custom_minimum_size = Vector2(440, 0)
	root.add_child(pause_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	pause_panel.add_child(pv)
	pv.add_child(UiKit.neon_title("ПАУЗА", 40, UiKit.P["magenta"]))
	var resume := UiKit.make_button("ПРОДОЛЖИТЬ", UiKit.P["green"])
	resume.pressed.connect(toggle_pause)
	pv.add_child(resume)
	var buy := UiKit.make_button("АРСЕНАЛ", UiKit.P["cyan"])
	buy.pressed.connect(func() -> void: toggle_buy())
	pv.add_child(buy)
	var restart := UiKit.make_button("ЗАНОВО", UiKit.P["amber"])
	restart.pressed.connect(func() -> void:
		get_tree().paused = false
		GameFlow.start_solo(true))
	pv.add_child(restart)
	var quit := UiKit.make_button("В МЕНЮ", UiKit.P["red"])
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		paused = false
		GameFlow.back_to_menu())
	pv.add_child(quit)
	pause_panel.visible = false
	# possession prompt
	possession_panel = PanelContainer.new()
	possession_panel.add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.02, 0.03, 0.03, 0.92), Color(0.2, 0.9, 0.6, 0.7), 1, 4))
	possession_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	possession_panel.position = Vector2(-240, -250)
	possession_panel.custom_minimum_size = Vector2(480, 0)
	root.add_child(possession_panel)
	var pv2 := VBoxContainer.new()
	pv2.add_theme_constant_override("separation", 6)
	possession_panel.add_child(pv2)
	pv2.add_child(UiKit.make_label("ТЫ МЁРТВ. ВСЕЛИСЬ В БОЙЦА СВОЕЙ КОМАНДЫ.", 15, UiKit.P["green"]))
	possession_buttons = VBoxContainer.new()
	pv2.add_child(possession_buttons)
	possession_panel.visible = false
	# end screen container (built on demand)
	end_panel = PanelContainer.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.015, 0.012, 0.03, 0.94), Color(0.4, 0.2, 0.55, 0.4), 0, 0))
	root.add_child(end_panel)
	end_panel.visible = false
	replay_panel = PanelContainer.new()
	replay_panel.add_theme_stylebox_override("panel", UiKit.stylebox(Color(0.02, 0.015, 0.04, 0.95), Color(0.9, 0.2, 0.8, 0.6), 1, 4))
	replay_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	replay_panel.position = Vector2(-320, -200)
	replay_panel.custom_minimum_size = Vector2(640, 400)
	root.add_child(replay_panel)
	replay_panel.visible = false


# ---------------------------------------------------------------------------
# TICK
# ---------------------------------------------------------------------------

func bind_player(_p: Actor) -> void:
	possession_panel.visible = false


var _tick_skip := 0
var _aim_world := Vector2.ZERO


func tick(delta: float) -> void:
	t += delta
	_tick_skip += 1
	# vitals + crosshair every frame, text/minimap-heavy parts at 30 Hz
	_tick_vitals(delta)
	if _tick_skip % 2 == 0:
		_tick_panels(delta)


func _tick_vitals(_delta: float) -> void:
	var p = world.get("local_actor")
	if p == null or not is_instance_valid(p):
		return
	# vitals
	hp_bar.value = p.hp / maxf(1.0, p.max_hp) * 100.0
	var hurt := clampf(1.0 - p.hp / maxf(1.0, p.max_hp), 0.0, 1.0)
	var alarm_pulse := clampf(float(world.get("alarm_level")) / 2.0, 0.0, 1.0) * 0.45
	Ui.set_pulse(maxf(hurt * 0.9, alarm_pulse))
	armor_bar.value = (p.armor / maxf(1.0, maxf(p.max_armor, 1.0))) * 100.0
	stamina_bar.value = p.stamina
	if p.downed:
		hp_label.text = "РАНЕН — %d" % int(maxf(0.0, 34.0 - p.downed_timer))
	else:
		hp_label.text = "%d HP" % int(p.hp)
	# weapon
	var w: Dictionary = p.weapon_stats()
	var wn: Label = weapon_card.get_node("WeaponName")
	wn.text = str(w.get("name", ""))
	ammo_label.text = "%d / %d" % [p.mag, p.reserve]
	if p.reload_timer > 0.0:
		ammo_label.text = "ПЕРЕЗАРЯДКА"
		ammo_label.add_theme_color_override("font_color", UiKit.P["amber"])
	else:
		ammo_label.add_theme_color_override("font_color", UiKit.P["bone"] if p.mag > 0 else UiKit.P["red"])
	ammo_label.add_theme_color_override("font_color", UiKit.P["bone"] if p.mag > 0 else UiKit.P["red"])
	var gadgets: Array[String] = []
	for g in ["grenade", "flashbang", "smoke", "molotov", "remote_charge", "medkit", "c4", "drill", "keycard"]:
		var n := int(p.gadget_charges.get(g, 0))
		if n > 0:
			gadgets.append("%s x%d" % [str(Db.WEAPONS.get(g, {}).get("short", g)), n])
	gadget_label.text = "  ".join(gadgets)
	# crosshair spread
	var sw: Dictionary = p.weapon_stats()
	crosshair.spread = p.current_accuracy_spread() * 1.5
	crosshair.show = not p.downed and not p.dead
	_aim_world = p.global_position


func _tick_panels(_delta: float) -> void:
	var p = world.get("local_actor")
	if p == null or not is_instance_valid(p):
		return
	# timer / score
	var elapsed := float(world.get("elapsed"))
	timer_label.text = Util.fmt_time(elapsed)
	var sc: Dictionary = world.get("team_score")
	score_label.text = "%d  :  %d" % [int(sc.get(0, 0)), int(sc.get(1, 0))]
	mode_label.text = str(Db.MODES.get(str(world.get("cfg").get("mode", "")), {}).get("name", ""))
	if net_label != null:
		net_label.text = str(world.get_meta("net_line", ""))
	# alarm / police
	var alarm := int(world.get("alarm_level"))
	if alarm >= 2:
		alarm_label.text = "ТРЕВОГА"
		alarm_label.add_theme_color_override("font_color", UiKit.P["red"])
	elif alarm == 1:
		alarm_label.text = "ПОДОЗРЕНИЕ"
		alarm_label.add_theme_color_override("font_color", UiKit.P["amber"])
	else:
		alarm_label.text = "ТИХО"
		alarm_label.add_theme_color_override("font_color", UiKit.P["green"])
	var et := float(world.get("police_arrive_timer"))
	if et > 0.0 and not bool(world.get("police_arrived")):
		alarm_label.text += "  |  КОПЫ: %s" % Util.fmt_time(et)
	elif bool(world.get("police_arrived")):
		alarm_label.text += "  |  КОПЫ НА МЕСТЕ"
	# interaction
	if p.interact_target != null:
		interact_bar.value = p.interact_progress() * 100.0
	else:
		interact_bar.value = 0.0
	# possession overlay
	if p.dead and not end_shown:
		if not possession_panel.visible:
			show_possession_prompt()
	else:
		possession_panel.visible = false
	# scoreboard live refresh
	if scoreboard_visible and fmod(t, 0.4) < 0.02:
		_rebuild_scoreboard()
	# buy menu live money
	if buy_panel.visible and buy_panel.has_method("refresh"):
		buy_panel.call("refresh")
	if command_open:
		command_wheel.queue_redraw()


func _process(_delta: float) -> void:
	if buy_panel != null and buy_panel.visible and Input.is_action_just_pressed("pause"):
		buy_panel.visible = false


func _on_event(text: String, color: Color, _icon: String) -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.015, 0.04, 0.75)
	sb.border_width_left = 3
	sb.border_color = color
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", sb)
	var l := UiKit.make_label(text, 16, color.lerp(Color.WHITE, 0.3))
	panel.add_child(l)
	event_log.add_child(panel)
	while event_log.get_child_count() > 4:
		var old_ev := event_log.get_child(0)
		event_log.remove_child(old_ev)
		old_ev.queue_free()
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(5.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free())


func _on_objective(title: String, detail: String, progress: float) -> void:
	if detail != "":
		objective_label.text = "◆ %s — %s" % [title, detail]
	else:
		objective_label.text = "◆ " + title
	objective_label.add_theme_color_override("font_color", UiKit.P["cyan"].lerp(UiKit.P["green"], clampf(progress, 0.0, 1.0)))


func _on_killfeed(entry: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 6)
	var kc: Color = Db.TEAM_COLORS.get(int(entry.get("killer_team", 2)), Color.WHITE)
	var vc: Color = Db.TEAM_COLORS.get(int(entry.get("victim_team", 2)), Color.WHITE)
	if bool(entry.get("civ", false)):
		vc = Color("c8b98a")
	var kl := UiKit.make_label("%s" % str(entry.get("killer", "")), 14, kc)
	var wl := UiKit.make_label(_weapon_glyph(str(entry.get("weapon", ""))), 13, UiKit.P["grey"])
	var vl := UiKit.make_label(str(entry.get("victim", "")), 14, vc)
	if bool(entry.get("headshot", false)):
		wl.text = "✦ " + wl.text + " ✦"
		wl.add_theme_color_override("font_color", UiKit.P["red"])
	h.add_child(kl)
	h.add_child(wl)
	h.add_child(vl)
	killfeed_box.add_child(h)
	if entry.get("victim_team", 0) == int(world.get("cfg").get("team", 0)) and not bool(entry.get("civ", false)):
		damage_flash.set("amount", 0.5)
	while killfeed_box.get_child_count() > 6:
		var old_kf := killfeed_box.get_child(0)
		killfeed_box.remove_child(old_kf)
		old_kf.queue_free()
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(h, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		if is_instance_valid(h):
			h.queue_free())


func _weapon_glyph(w: String) -> String:
	var kind := str(Db.WEAPONS.get(w, {}).get("kind", ""))
	match kind:
		"rifle":
			return "▬▬"
		"smg":
			return "▬"
		"pistol":
			return "▫"
		"shotgun":
			return "▮▮"
		"sniper":
			return "➶"
		"melee":
			return "✕"
		"throw":
			return "◎"
		"lmg":
			return "▬▬▬"
		"special":
			return "☠"
	return "•"


func _on_alarm(level: int, reason: String) -> void:
	if level >= 2:
		damage_flash.set("amount", 0.7)
		_on_event("ТРЕВОГА: " + reason, Color("ff1f4b"), "alarm")


func _on_score(_team: int, _score_value: int) -> void:
	pass


func _on_prompt(text: String, vis: bool) -> void:
	interact_label.text = text
	interact_label.visible = vis


# ---------------------------------------------------------------------------
# OVERLAYS
# ---------------------------------------------------------------------------

func set_scoreboard(vis: bool) -> void:
	scoreboard_visible = vis
	scoreboard.visible = vis
	if vis:
		_rebuild_scoreboard()


func _rebuild_scoreboard() -> void:
	for c in scoreboard_rows.get_children():
		scoreboard_rows.remove_child(c)
		c.queue_free()
	scoreboard_rows.add_child(UiKit.neon_title("ТАБЛО", 28, UiKit.P["magenta"]))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	for h_text in ["ИМЯ", "ФРАГИ", "СМЕРТИ", "СЧЁТ", "ДЕНЬГИ"]:
		var l := UiKit.make_label(h_text, 12, UiKit.P["grey"])
		l.custom_minimum_size = Vector2(120 if h_text == "ИМЯ" else 90, 0)
		header.add_child(l)
	scoreboard_rows.add_child(header)
	scoreboard_rows.add_child(UiKit.make_separator())
	var rows: Array = world.call("scoreboard_rows_data")
	for r in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var col: Color = Db.TEAM_COLORS.get(int(r["team"]), Color.WHITE)
		var name_l := UiKit.make_label(("◆ " if not bool(r["bot"]) else "  ") + str(r["name"]), 15, col)
		name_l.custom_minimum_size = Vector2(120, 0)
		line.add_child(name_l)
		if not bool(r["alive"]):
			name_l.modulate.a = 0.5
		for key in ["kills", "deaths", "score", "money"]:
			var val := str(r[key])
			if key == "money":
				val = Util.fmt_cash(int(r[key]))
			var vl := UiKit.make_label(val, 14, UiKit.P["bone"])
			vl.custom_minimum_size = Vector2(90, 0)
			line.add_child(vl)
		scoreboard_rows.add_child(line)


func toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	pause_panel.visible = paused
	world.set("paused", paused)


func toggle_buy() -> void:
	if buy_panel == null:
		return
	var p = world.get("local_actor")
	if p != null and p.dead:
		Signals.notify.emit("Магазин недоступен после смерти", "warning")
		return
	buy_panel.visible = not buy_panel.visible
	if buy_panel.visible and buy_panel.has_method("open"):
		buy_panel.call("open")


func open_command_wheel() -> void:
	command_open = true
	command_wheel.visible = true
	command_wheel.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void:
		command_open = false
		command_wheel.visible = false)


func is_command_wheel_open() -> bool:
	return command_open


func command_at(screen_pos: Vector2) -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	var dir := screen_pos - center
	var idx := 0
	if dir.length() > 30.0:
		var ang := dir.angle() + PI * 0.5
		if ang < 0:
			ang += TAU
		idx = int(round(ang / (TAU / 4.0))) % 4
	var kinds := ["advance", "flank", "hold", "retreat"]
	world.call("order_all", kinds[idx])
	command_open = false
	command_wheel.visible = false


func show_possession_prompt() -> void:
	possession_panel.visible = true
	for c in possession_buttons.get_children():
		possession_buttons.remove_child(c)
		c.queue_free()
	var team: int = int(world.get("cfg").get("team", 0))
	var count := 0
	for a in world.get("actors"):
		if a.is_civilian or a.dead or a.team != team or not a.is_bot:
			continue
		var b := UiKit.make_button("ВСЕЛИТЬСЯ В %s" % a.a_name, UiKit.P["green"], 14)
		b.custom_minimum_size = Vector2(0, 34)
		var aid: int = a.a_id
		b.pressed.connect(func() -> void:
			world.call("possess", aid)
			possession_panel.visible = false)
		possession_buttons.add_child(b)
		count += 1
		if count >= 3:
			break
	if count == 0:
		var l := UiKit.make_label("Вселения недоступны. Наблюдение.", 13, UiKit.P["grey"])
		possession_buttons.add_child(l)
	var q := UiKit.make_small_button("Q — ближайший боец", UiKit.P["cyan"])
	q.pressed.connect(func() -> void:
		world.call("try_possession")
		possession_panel.visible = false)
	possession_buttons.add_child(q)


func flash_bad(text: String) -> void:
	_on_event(text, Color("ff1f4b"), "bad")
	damage_flash.set("amount", 0.8)


func show_end(summary: Dictionary) -> void:
	if end_shown:
		return
	end_shown = true
	end_panel.visible = true
	for c in end_panel.get_children():
		end_panel.remove_child(c)
		c.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_bottom", 70)
	end_panel.add_child(margin)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 40)
	margin.add_child(box)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	box.add_child(left)
	var p_team: int = int(world.get("cfg").get("team", 0))
	var won := int(summary.get("winner", -1)) == p_team
	left.add_child(UiKit.neon_title("ПОБЕДА" if won else "ПОРАЖЕНИЕ", 58, UiKit.P["green"] if won else UiKit.P["red"]))
	left.add_child(UiKit.make_label(str(summary.get("reason", "")), 17, UiKit.P["bone"]))
	left.add_child(UiKit.make_vspace(16))
	var pl: Dictionary = summary.get("player", {})
	left.add_child(_stat_row("Фраги", str(pl.get("kills", 0))))
	left.add_child(_stat_row("Смерти", str(pl.get("deaths", 0))))
	left.add_child(_stat_row("В голову", str(pl.get("headshots", 0))))
	left.add_child(_stat_row("Счёт", str(pl.get("score", 0))))
	left.add_child(_stat_row("Заработано", Util.fmt_cash(int(pl.get("money", 0)))))
	left.add_child(UiKit.make_vspace(20))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var again := UiKit.make_button("ЕЩЁ РАЗ", UiKit.P["magenta"])
	again.pressed.connect(func() -> void: GameFlow.start_solo(true))
	btns.add_child(again)
	var menu := UiKit.make_button("В МЕНЮ", UiKit.P["cyan"])
	menu.pressed.connect(func() -> void: GameFlow.back_to_menu())
	btns.add_child(menu)
	left.add_child(btns)
	# right: highlight replay
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	box.add_child(right)
	right.add_child(UiKit.make_label("ЛУЧШИЙ МОМЕНТ", 16, UiKit.P["magenta"]))
	var clip: Dictionary = summary.get("replay", {})
	if clip.is_empty():
		right.add_child(UiKit.make_label("Моментов не было. Только работа.", 14, UiKit.P["grey"]))
	else:
		var viewer := load("res://src/ui/replay_viewer.gd").new()
		viewer.set("clip", clip)
		viewer.set("world", world)
		viewer.set("autoplay", true)
		viewer.custom_minimum_size = Vector2(620, 340)
		right.add_child(viewer)


func _stat_row(label: String, value: String) -> Control:
	var h := HBoxContainer.new()
	var l := UiKit.make_label(label, 16, UiKit.P["grey"])
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	h.add_child(UiKit.make_label(value, 18, UiKit.P["bone"]))
	return h


func _on_replay(clip: Dictionary) -> void:
	if end_shown:
		return
	var viewer := load("res://src/ui/replay_viewer.gd").new()
	viewer.set("clip", clip)
	viewer.set("world", world)
	viewer.set("autoplay", true)
	for c in replay_panel.get_children():
		replay_panel.remove_child(c)
		c.queue_free()
	replay_panel.add_child(viewer)
	replay_panel.visible = true
	replay_panel.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_callback(func() -> void: replay_panel.visible = false)
