class_name LoadoutScreen
extends Control
## Briefing + equipment selection: side, task, map features, roles, weapons,
## gadgets, armour. The same screen is used from the lobby and standalone.

signal confirmed(loadout: Dictionary)
signal back_requested

var mode_id: String = "plant"
var map_id: String = "clinic"
var team: int = GameTypes.Team.CRIMINALS
var loadout: Dictionary = {}

var primary_option: OptionButton
var secondary_option: OptionButton
var gadget_option: OptionButton
var armor_option: OptionButton
var role_option: OptionButton
var briefing_box: VBoxContainer
var stats_label: Label
var title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if loadout.is_empty():
		loadout = {
			"primary": "kv14" if team == GameTypes.Team.POLICE else "vec9",
			"secondary": "p9",
			"gadget": "flash",
			"armor": 1,
			"medkits": 1,
			"role": GameTypes.Role.OBSERVER,
		}
	_build()
	_refresh()


func setup(mode: String, map: String, for_team: int) -> void:
	mode_id = mode
	map_id = map
	team = for_team


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.015, 0.025, 0.04, 0.97)
	add_child(bg)
	title = _label("", 34)
	title.position = Vector2(50, 30)
	add_child(title)
	var back := Button.new()
	back.text = Localization.t("back")
	back.position = Vector2(50, 1000)
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(_on_back)
	add_child(back)
	var ok := Button.new()
	ok.text = Localization.t("loadout_confirm")
	ok.position = Vector2(1700, 1000)
	ok.custom_minimum_size = Vector2(170, 46)
	ok.add_theme_font_size_override("font_size", 20)
	ok.pressed.connect(_on_confirm)
	add_child(ok)
	# Briefing
	var briefing_panel := PanelContainer.new()
	briefing_panel.position = Vector2(50, 110)
	briefing_panel.custom_minimum_size = Vector2(980, 820)
	briefing_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(briefing_panel)
	briefing_box = VBoxContainer.new()
	briefing_box.add_theme_constant_override("separation", 8)
	briefing_panel.add_child(briefing_box)
	# Equipment
	var equip_panel := PanelContainer.new()
	equip_panel.position = Vector2(1060, 110)
	equip_panel.custom_minimum_size = Vector2(810, 820)
	equip_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(equip_panel)
	var equip_box := VBoxContainer.new()
	equip_box.add_theme_constant_override("separation", 8)
	equip_panel.add_child(equip_box)
	equip_box.add_child(_label(Localization.t("loadout_title"), 24))
	role_option = OptionButton.new()
	for role in Data.roles():
		role_option.add_item(Localization.t("role_" + String(role.get("id", ""))))
	role_option.item_selected.connect(_on_role)
	equip_box.add_child(_row(Localization.t("loadout_role"), role_option))
	primary_option = OptionButton.new()
	primary_option.item_selected.connect(_on_equipment)
	equip_box.add_child(_row(Localization.t("loadout_primary"), primary_option))
	secondary_option = OptionButton.new()
	secondary_option.item_selected.connect(_on_equipment)
	equip_box.add_child(_row(Localization.t("loadout_secondary"), secondary_option))
	gadget_option = OptionButton.new()
	gadget_option.item_selected.connect(_on_equipment)
	equip_box.add_child(_row(Localization.t("loadout_gadget"), gadget_option))
	armor_option = OptionButton.new()
	armor_option.add_item(Localization.t("armor_none"))
	armor_option.add_item(Localization.t("armor_light"))
	armor_option.add_item(Localization.t("armor_heavy"))
	armor_option.item_selected.connect(_on_equipment)
	equip_box.add_child(_row(Localization.t("loadout_armor"), armor_option))
	stats_label = _label("", 17)
	stats_label.autowrap = TextServer.AUTOWRAP_WORD_SMART
	stats_label.custom_minimum_size = Vector2(760, 320)
	equip_box.add_child(stats_label)


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


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := _label(label_text, 17)
	label.custom_minimum_size = Vector2(190, 32)
	row.add_child(label)
	row.add_child(control)
	return row


func _refresh() -> void:
	var mode_data := Data.mode(mode_id)
	var map_data := Data.map(map_id)
	title.text = GameTypes.team_name(team) + " — " + Localization.t("mode_" + mode_id)
	for child in briefing_box.get_children():
		child.queue_free()
	_add_briefing_line("briefing_side", GameTypes.team_name(team))
	_add_briefing_line("briefing_task", Localization.t("mode_" + mode_id) + ": " + String(mode_data.get("short", "")))
	_add_briefing_line("briefing_map", Localization.t("map_" + map_id) + " — " + String(map_data.get("description", "")))
	_add_briefing_line("briefing_civilians", Localization.t("briefing_civilians_yes") if bool(mode_data.get("civilians", true)) else Localization.t("briefing_civilians_no"))
	if mode_data.has("police_delay"):
		_add_briefing_line("briefing_police_delay", U.format_time(float(config_delay(mode_data))))
	_add_briefing_line("briefing_restrictions", String(mode_data.get("description", "")))
	# Equipment options
	_populate_weapons()
	role_option.selected = clampi(int(loadout.get("role", 0)), 0, maxi(0, role_option.item_count - 1))
	_on_role(role_option.selected)
	armor_option.selected = int(loadout.get("armor", 1))
	_update_stats()


func config_delay(mode_data: Dictionary) -> float:
	return float(mode_data.get("police_delay", 60.0))


func _add_briefing_line(key: String, value: String) -> void:
	var label := _label(Localization.t(key) + ": " + value, 18)
	label.autowrap = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(930, 0)
	briefing_box.add_child(label)


func _populate_weapons() -> void:
	primary_option.clear()
	secondary_option.clear()
	var primary_index := 0
	var secondary_index := 0
	for weapon in Data.weapons():
		var wid := String(weapon.get("id", ""))
		var class_name: String = weapon.get("class", "")
		if class_name == "melee":
			continue
		if class_name == "pistol":
			secondary_option.add_item(String(weapon.get("name", wid)))
			if wid == String(loadout.get("secondary", "p9")):
				secondary_index = secondary_option.item_count - 1
		else:
			primary_option.add_item(String(weapon.get("name", wid)))
			if wid == String(loadout.get("primary", "")):
				primary_index = primary_option.item_count - 1
	primary_option.selected = clampi(primary_index, 0, maxi(0, primary_option.item_count - 1))
	secondary_option.selected = clampi(secondary_index, 0, maxi(0, secondary_option.item_count - 1))


func _on_role(index: int) -> void:
	if index < 0 or index >= Data.roles().size():
		return
	var role: Dictionary = Data.roles()[index]
	loadout["role"] = index
	gadget_option.clear()
	gadget_option.add_item(Localization.t("gadget_" + String(role.get("gadget", "flash"))))
	match index:
		GameTypes.Role.MEDIC:
			gadget_option.add_item(Localization.t("gadget_medkit"))
		GameTypes.Role.SUPPORT:
			gadget_option.add_item(Localization.t("gadget_ammo"))
		GameTypes.Role.OBSERVER:
			gadget_option.add_item(Localization.t("gadget_camera"))
		GameTypes.Role.TECHNICIAN:
			gadget_option.add_item(Localization.t("gadget_breach"))
		GameTypes.Role.NEGOTIATOR:
			gadget_option.add_item(Localization.t("gadget_radio"))
		GameTypes.Role.GUARDIAN:
			gadget_option.add_item(Localization.t("gadget_armor"))
	gadget_option.selected = 0
	loadout["gadget"] = String(role.get("gadget", "flash"))
	_update_stats()


func _on_equipment(_index: int) -> void:
	if primary_option.selected >= 0 and primary_option.item_count > 0:
		var primary_name := primary_option.get_item_text(primary_option.selected)
		for weapon in Data.weapons():
			if String(weapon.get("name", "")) == primary_name:
				loadout["primary"] = String(weapon.get("id", "kv14"))
	if secondary_option.selected >= 0 and secondary_option.item_count > 0:
		var secondary_name := secondary_option.get_item_text(secondary_option.selected)
		for weapon in Data.weapons():
			if String(weapon.get("name", "")) == secondary_name:
				loadout["secondary"] = String(weapon.get("id", "p9"))
	if gadget_option.selected >= 0 and gadget_option.item_count > 0:
		var gadget_text := gadget_option.get_item_text(gadget_option.selected)
		for key in ["flash", "smoke", "medkit", "ammo", "armor", "camera", "breach", "radio"]:
			if Localization.t("gadget_" + key) == gadget_text:
				loadout["gadget"] = key
	loadout["armor"] = armor_option.selected
	_update_stats()


func _update_stats() -> void:
	var text := ""
	var primary := Data.weapon(String(loadout.get("primary", "")))
	if not primary.is_empty():
		text += Localization.t("stat_damage") + ": " + str(int(primary.get("damage", 0))) + "\n"
		text += Localization.t("stat_rpm") + ": " + str(int(primary.get("rpm", 0))) + "\n"
		text += Localization.t("stat_mag") + ": " + str(int(primary.get("mag", 0))) + "\n"
		text += Localization.t("stat_reload") + ": " + str(primary.get("reload", 0)) + "\n"
		text += primary.get("desc", "") + "\n\n"
	var role: Dictionary = Data.role(String(["observer", "technician", "medic", "support", "negotiator", "guardian"][int(loadout.get("role", 0))]))
	text += Localization.t("role_title") + ": " + String(role.get("name", "")) + "\n"
	text += String(role.get("desc", "")) + "\n"
	stats_label.text = text


func _on_confirm() -> void:
	AudioManager.ui_click()
	Game.loadout = loadout.duplicate(true)
	confirmed.emit(loadout)
	back_requested.emit()


func _on_back() -> void:
	AudioManager.ui_click()
	back_requested.emit()
