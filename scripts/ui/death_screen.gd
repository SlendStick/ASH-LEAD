class_name DeathScreen
extends Control
## Death / downed overlay: spectate a teammate or take control of a live bot.

var hud: HUD
var match_ref: Match
var dim: ColorRect
var panel: PanelContainer
var title: Label
var info_label: Label
var bots_box: VBoxContainer
var spectate_button: Button
var _open: bool = false
var _spectate_index: int = 0
var _downed_timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(960 - 260, 180)
	panel.custom_minimum_size = Vector2(520, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.07, 0.94)
	style.border_color = Color(0.5, 0.15, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title = Label.new()
	title.text = Localization.t("death_title")
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 17)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.modulate = Color(0.8, 0.85, 0.9)
	info_label.autowrap = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_label)
	spectate_button = Button.new()
	spectate_button.text = Localization.t("spectate_teammate")
	spectate_button.add_theme_font_size_override("font_size", 18)
	spectate_button.pressed.connect(_on_spectate)
	box.add_child(spectate_button)
	var bots_title := Label.new()
	bots_title.text = Localization.t("take_control_title")
	bots_title.add_theme_font_size_override("font_size", 19)
	box.add_child(bots_title)
	bots_box = VBoxContainer.new()
	bots_box.add_theme_constant_override("separation", 6)
	box.add_child(bots_box)


func open(info: Dictionary) -> void:
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var downed: bool = bool(info.get("downed", false))
	if downed:
		title.text = Localization.t("downed_title")
		info_label.text = Localization.t("downed_hint")
		spectate_button.visible = false
		bots_box.visible = false
		_open = true
		visible = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_downed_timer = 6.0
		return
	title.text = Localization.t("death_title")
	var character: Character = info.get("character", null)
	var killer_name := ""
	if character != null and character.has_meta("last_killer"):
		killer_name = String(character.get_meta("last_killer"))
	info_label.text = Localization.t("death_hint")
	spectate_button.visible = true
	bots_box.visible = true
	_rebuild_bots(info)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.play("round_lose", Vector2.INF, -10.0)


func close() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hud != null and hud.match_ref != null and not hud.match_ref.finished:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	if _open and not spectate_button.visible:
		_downed_timer -= delta
		if _downed_timer <= 0.0:
			close()


func _rebuild_bots(info: Dictionary) -> void:
	for child in bots_box.get_children():
		child.queue_free()
	var bots: Array = info.get("bots", [])
	if bots.is_empty():
		var label := Label.new()
		label.text = Localization.t("no_bots_available")
		label.add_theme_font_size_override("font_size", 16)
		label.modulate = Color(0.8, 0.6, 0.5)
		bots_box.add_child(label)
		return
	for bot in bots:
		var button := Button.new()
		button.text = bot.char_name + "  ·  " + GameTypes.role_name(bot.role)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_take_control.bind(bot))
		bots_box.add_child(button)


func _on_spectate() -> void:
	if hud == null:
		return
	_spectate_index += 1
	var teammates: Array = []
	if match_ref != null and match_ref.local_player != null:
		for c in match_ref.characters:
			if c.team == match_ref.local_player.team and c.alive and not c.downed:
				teammates.append(c)
	if teammates.is_empty():
		return
	var target: Character = teammates[_spectate_index % teammates.size()]
	hud.spectate_requested.emit(target)
	AudioManager.ui_click()


func _on_take_control(bot: Character) -> void:
	if hud == null or match_ref == null:
		return
	hud.take_control_requested.emit(bot)
	close()
	AudioManager.ui_click()
