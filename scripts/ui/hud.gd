class_name HUD
extends CanvasLayer
## In-match interface: minimap with fog of war, timer/phase, objective,
## teammates, weapon/ammo, hints, event feed, interaction progress, overlays.

signal order_selected(type: int)
signal resume_requested
signal spectate_requested(character: Character)
signal take_control_requested(bot: Character)
signal restart_requested
signal menu_requested

var match_ref: Match
var root: Control
var phase_label: Label
var timer_label: Label
var score_label: Label
var resonance_label: Label
var objective_label: Label
var hint_label: Label
var progress_bar: ProgressBar
var feed_box: VBoxContainer
var team_box: VBoxContainer
var weapon_name_label: Label
var ammo_label: Label
var gadget_label: Label
var hp_label: Label
var minimap
var vignette: TextureRect
var crosshair: Control
var order_wheel
var scoreboard
var map_overlay
var death_screen
var civilian_menu
var negotiation_menu
var status_label: Label
var _vignette_texture: Texture2D
var _last_hint := ""


func _ready() -> void:
	layer = 5
	_build()


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_vignette_texture = _make_vignette()
	_build_top_bar()
	_build_minimap()
	_build_team_panel()
	_build_weapon_panel()
	_build_hint()
	_build_feed()
	_build_crosshair()
	_build_vignette()
	_build_overlays()


func _panel_style(alpha: float = 0.72) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.07, alpha)
	style.border_color = Color(0.16, 0.22, 0.3, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _label(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.position = Vector2(960 - 260, 8)
	bar.add_theme_stylebox_override("panel", _panel_style(0.6))
	root.add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	bar.add_child(hbox)
	phase_label = _label("", 20)
	timer_label = _label("", 24)
	score_label = _label("", 20)
	resonance_label = _label("", 16)
	hbox.add_child(phase_label)
	hbox.add_child(timer_label)
	hbox.add_child(score_label)
	hbox.add_child(resonance_label)
	status_label = _label("", 15)
	status_label.position = Vector2(960 - 260, 62)
	root.add_child(status_label)


func _build_minimap() -> void:
	minimap = load("res://scripts/ui/minimap.gd").new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = -268
	minimap.offset_top = 10
	minimap.offset_right = -16
	minimap.offset_bottom = 214
	root.add_child(minimap)
	objective_label = _label("", 17)
	objective_label.position = Vector2(1920 - 280, 222)
	objective_label.custom_minimum_size = Vector2(264, 60)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(objective_label)


func _build_team_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 1080 - 250)
	panel.add_theme_stylebox_override("panel", _panel_style(0.55))
	root.add_child(panel)
	team_box = VBoxContainer.new()
	team_box.add_theme_constant_override("separation", 4)
	panel.add_child(team_box)


func _build_weapon_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -300
	panel.offset_right = -16
	panel.offset_top = -96
	panel.offset_bottom = -16
	panel.add_theme_stylebox_override("panel", _panel_style(0.6))
	root.add_child(panel)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	hbox.add_child(left)
	weapon_name_label = _label("", 19)
	ammo_label = _label("", 26)
	hp_label = _label("", 17)
	left.add_child(weapon_name_label)
	left.add_child(ammo_label)
	left.add_child(hp_label)
	gadget_label = _label("", 16)
	hbox.add_child(gadget_label)


func _build_hint() -> void:
	hint_label = _label("", 18)
	hint_label.position = Vector2(960 - 220, 1080 - 150)
	hint_label.custom_minimum_size = Vector2(440, 26)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint_label)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(960 - 150, 1080 - 118)
	progress_bar.custom_minimum_size = Vector2(300, 12)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.modulate = Color(0.2, 0.9, 0.7)
	root.add_child(progress_bar)


func _build_feed() -> void:
	feed_box = VBoxContainer.new()
	feed_box.position = Vector2(18, 250)
	feed_box.add_theme_constant_override("separation", 2)
	feed_box.custom_minimum_size = Vector2(360, 0)
	root.add_child(feed_box)


func _build_crosshair() -> void:
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.script = load("res://scripts/ui/crosshair.gd")
	root.add_child(crosshair)


func _build_vignette() -> void:
	vignette = TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.texture = _vignette_texture
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate = Color(1, 1, 1, 0)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(vignette)


func _build_overlays() -> void:
	order_wheel = load("res://scripts/ui/order_wheel.gd").new()
	order_wheel.hud = self
	root.add_child(order_wheel)
	scoreboard = load("res://scripts/ui/scoreboard.gd").new()
	scoreboard.hud = self
	root.add_child(scoreboard)
	map_overlay = load("res://scripts/ui/map_overlay.gd").new()
	map_overlay.hud = self
	root.add_child(map_overlay)
	death_screen = load("res://scripts/ui/death_screen.gd").new()
	death_screen.hud = self
	root.add_child(death_screen)
	civilian_menu = load("res://scripts/ui/civilian_menu.gd").new()
	civilian_menu.hud = self
	root.add_child(civilian_menu)
	negotiation_menu = load("res://scripts/ui/negotiation_menu.gd").new()
	negotiation_menu.hud = self
	root.add_child(negotiation_menu)


# ---- lifecycle -------------------------------------------------------------

func on_match_started(match_ref: Match) -> void:
	match_ref = match_ref
	minimap.match_ref = match_ref
	scoreboard.match_ref = match_ref
	map_overlay.match_ref = match_ref
	death_screen.match_ref = match_ref
	civilian_menu.match_ref = match_ref
	negotiation_menu.match_ref = match_ref
	order_wheel.match_ref = match_ref
	RebuildTeamList()
	objective_label.text = match_ref.mode.get_objective_text() if match_ref.mode != null else ""
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func update_hud(match_ref: Match, delta: float) -> void:
	match_ref = match_ref
	if match_ref.finished:
		return
	var phase_text := ""
	if match_ref.mode != null:
		phase_text = match_ref.mode.get_phase_text()
		objective_label.text = match_ref.mode.get_objective_text()
	phase_label.text = phase_text
	timer_label.text = U.format_time(maxf(0.0, match_ref.round_time_left()))
	if match_ref.mode != null:
		score_label.text = "%d : %d" % [match_ref.mode.get_score(GameTypes.Team.CRIMINALS), match_ref.mode.get_score(GameTypes.Team.POLICE)]
	resonance_label.text = "%s %d%%" % [match_ref.resonance.level_name(), int(match_ref.resonance.value)]
	status_label.text = _status_text()
	progress_bar.value = match_ref.local_player.get_interact_progress() if match_ref.local_player != null else 0.0
	_update_weapon()
	_update_teammates(delta)
	_update_vignette(delta)
	minimap.queue_redraw()
	map_overlay.queue_redraw()


func _status_text() -> String:
	if match_ref.local_player == null:
		return ""
	var c := match_ref.local_player
	var text := "%s  ·  %s" % [c.char_name, GameTypes.role_name(c.role)]
	if c.carry_object:
		text += "  ·  " + Localization.t("carrying")
	if c.stealth_mode:
		text += "  ·  " + Localization.t("stealth")
	return text


func _update_weapon() -> void:
	if match_ref.local_player == null:
		return
	var c := match_ref.local_player
	var weapon := c.get_weapon()
	if weapon == null:
		return
	weapon_name_label.text = weapon.name
	if weapon.is_melee:
		ammo_label.text = Localization.t("melee")
	else:
		ammo_label.text = "%d / %d" % [weapon.ammo_in_mag, weapon.reserve]
	hp_label.text = "%s %d   %s %d" % [Localization.t("health"), c.hp, Localization.t("armor"), c.armor]
	var gadget_text := ""
	for g in c.gadgets:
		gadget_text += Localization.t("gadget_" + String(g)) + " "
	gadget_label.text = gadget_text


func _update_teammates(delta: float) -> void:
	if team_box == null:
		return
	if team_box.get_child_count() != _teammate_entries().size():
		RebuildTeamList()
	var index := 0
	for entry in _teammate_entries():
		if index >= team_box.get_child_count():
			break
		var row: HBoxContainer = team_box.get_child(index)
		var bar: ProgressBar = row.get_node_or_null("Bar")
		var name_label: Label = row.get_node_or_null("Name")
		if bar != null:
			bar.max_value = maxi(1, entry["max_hp"])
			bar.value = entry["hp"]
		if name_label != null:
			name_label.text = ("%s%s" % ["● " if entry["alive"] else "✖ ", entry["name"]])
			name_label.modulate = Color(0.5, 0.95, 0.7) if entry["alive"] else Color(0.7, 0.3, 0.3)
		index += 1


func _teammate_entries() -> Array:
	var out: Array = []
	if match_ref == null or match_ref.local_player == null:
		return out
	for c in match_ref.characters:
		if c.team == match_ref.local_player.team and c.team != GameTypes.Team.CIVILIAN:
			out.append({"name": c.char_name, "hp": c.hp, "max_hp": c.max_hp, "alive": c.alive})
	return out


func RebuildTeamList() -> void:
	if team_box == null:
		return
	for child in team_box.get_children():
		child.queue_free()
	for entry in _teammate_entries():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := _label(entry["name"], 16)
		name_label.name = "Name"
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.name = "Bar"
		bar.custom_minimum_size = Vector2(90, 10)
		bar.show_percentage = false
		bar.modulate = Color(0.2, 0.9, 0.55)
		row.add_child(bar)
		team_box.add_child(row)


func _update_vignette(delta: float) -> void:
	if vignette == null or match_ref == null or match_ref.local_player == null:
		return
	var c := match_ref.local_player
	var damage := 1.0 - float(c.hp) / float(maxi(1, c.max_hp))
	var sup := c.suppression
	var target := clampf(damage * 0.55 + sup * 0.5, 0.0, 0.85)
	if c.downed:
		target = 0.9
	vignette.modulate.a = vignette.modulate.a + (target - vignette.modulate.a) * clampf(delta * 3.0, 0.0, 1.0)


func _make_vignette() -> Texture2D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - half, y - half).length() / half
			var a := clampf((d - 0.55) / 0.55, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.45, 0.02, 0.05, a * a))
	return ImageTexture.create_from_image(img)


# ---- public API ------------------------------------------------------------

func add_feed(text: String) -> void:
	if feed_box == null:
		return
	var label := _label(text, 15)
	label.modulate = Color(0.8, 0.86, 0.92, 0.9)
	feed_box.add_child(label)
	while feed_box.get_child_count() > 6:
		var first := feed_box.get_child(0)
		first.queue_free()


func set_hint(text: String) -> void:
	if text == _last_hint:
		return
	_last_hint = text
	if hint_label != null:
		hint_label.text = text


func open_civilian_commands(character: Character, civilian: Character) -> void:
	civilian_menu.open(character, civilian)


func open_negotiation(character: Character) -> void:
	negotiation_menu.open(character)


func show_death_screen(info: Dictionary) -> void:
	death_screen.open(info)


func close_all_overlays() -> void:
	order_wheel.close()
	scoreboard.close()
	map_overlay.close()
	death_screen.close()
	civilian_menu.close()
	negotiation_menu.close()
