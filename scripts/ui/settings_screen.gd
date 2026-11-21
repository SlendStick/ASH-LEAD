class_name SettingsScreen
extends Control
## Settings: audio, controls (rebind), accessibility, camera, interface.

signal back_requested

var tabs: Array = []
var current_tab: String = "controls"
var content: VBoxContainer
var rebind_target: String = ""
var rebind_button: Button = null
var status_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	InputManager.load_bindings()


func _build() -> void:
	_background()
	var title := _label(Localization.t("settings_title"), 40)
	title.position = Vector2(60, 40)
	add_child(title)
	var back := Button.new()
	back.text = Localization.t("back")
	back.position = Vector2(60, 1000)
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(_on_back)
	add_child(back)
	# Tabs
	var tab_box := HBoxContainer.new()
	tab_box.position = Vector2(60, 110)
	tab_box.add_theme_constant_override("separation", 6)
	add_child(tab_box)
	for tab in ["controls", "audio", "accessibility", "camera", "interface"]:
		var button := Button.new()
		button.text = Localization.t("settings_tab_" + tab)
		button.custom_minimum_size = Vector2(180, 42)
		button.pressed.connect(_on_tab.bind(tab))
		tab_box.add_child(button)
		tabs.append({"id": tab, "button": button})
	content = VBoxContainer.new()
	content.position = Vector2(60, 170)
	content.custom_minimum_size = Vector2(1780, 780)
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	status_label = _label("", 16)
	status_label.position = Vector2(60, 960)
	add_child(status_label)
	_show_tab("controls")


func _background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.045, 0.97)
	add_child(bg)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.97))
	return label


func _on_tab(tab: String) -> void:
	AudioManager.ui_click()
	_show_tab(tab)


func _show_tab(tab: String) -> void:
	current_tab = tab
	for child in content.get_children():
		child.queue_free()
	match tab:
		"controls":
			_build_controls()
		"audio":
			_build_audio()
		"accessibility":
			_build_accessibility()
		"camera":
			_build_camera()
		"interface":
			_build_interface()


# ---- controls --------------------------------------------------------------

func _build_controls() -> void:
	_add_header("settings_controls_hint")
	var actions := {
		"move_up": "action_move_up", "move_down": "action_move_down",
		"move_left": "action_move_left", "move_right": "action_move_right",
		"fire": "action_fire", "alt_fire": "action_alt_fire",
		"sprint": "action_sprint", "crouch": "action_crouch",
		"interact": "action_interact", "reload": "action_reload",
		"order_wheel": "action_order_wheel", "ping": "action_ping",
		"scoreboard": "action_scoreboard", "pause": "action_pause",
		"slot1": "action_slot1", "slot2": "action_slot2", "slot3": "action_slot3",
		"gadget": "action_gadget", "melee": "action_melee",
	}
	for action in actions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := _label(Localization.t(actions[action]), 18)
		name_label.custom_minimum_size = Vector2(300, 34)
		row.add_child(name_label)
		var events := InputManager.get_action_events(action)
		var text := ""
		for ev in events:
			text += _event_name(ev) + "  "
		var button := Button.new()
		button.text = text.strip_edges() if not text.is_empty() else "—"
		button.custom_minimum_size = Vector2(420, 34)
		button.pressed.connect(_on_rebind.bind(action, button))
		row.add_child(button)
		content.add_child(row)
	var reset := Button.new()
	reset.text = Localization.t("reset_bindings")
	reset.custom_minimum_size = Vector2(220, 40)
	reset.pressed.connect(_on_reset_bindings)
	content.add_child(reset)


func _event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return Key.get_string_from_code(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				return "ЛКМ"
			MOUSE_BUTTON_RIGHT:
				return "ПКМ"
			MOUSE_BUTTON_MIDDLE:
				return "СКМ"
	if ev is InputEventJoypadButton:
		return "ГП " + str(ev.button_index)
	return ev.as_text()


func _on_rebind(action: String, button: Button) -> void:
	rebind_target = action
	rebind_button = button
	status_label.text = Localization.t("rebind_hint")
	set_process_input(true)


func _on_reset_bindings() -> void:
	InputManager.reset_bindings()
	_show_tab("controls")
	status_label.text = Localization.t("bindings_reset")


func _input(event: InputEvent) -> void:
	if rebind_target.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		InputManager.set_binding(rebind_target, event)
		_finish_rebind()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
		InputManager.set_binding(rebind_target, event)
		_finish_rebind()
	elif event is InputEventJoypadButton and event.pressed:
		InputManager.set_binding(rebind_target, event)
		_finish_rebind()


func _finish_rebind() -> void:
	rebind_target = ""
	rebind_button = null
	status_label.text = Localization.t("binding_saved")
	_show_tab("controls")


# ---- sliders ---------------------------------------------------------------

func _add_slider(key: String, label_key: String, min_value: float, max_value: float, step_val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(Localization.t(label_key), 18)
	name_label.custom_minimum_size = Vector2(320, 34)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step_val
	slider.value = float(SettingsManager.get_setting(key))
	slider.custom_minimum_size = Vector2(420, 30)
	slider.value_changed.connect(_on_slider.bind(key))
	row.add_child(slider)
	var value_label := _label(str(slider.value), 16)
	value_label.custom_minimum_size = Vector2(90, 30)
	slider.value_changed.connect(func(v): value_label.text = _format_value(key, v))
	row.add_child(value_label)
	content.add_child(row)


func _format_value(key: String, value: float) -> String:
	if key == "mouse_sensitivity":
		return "%.2f" % value
	if key.begins_with("volume_"):
		return "%d%%" % int(value * 100.0)
	return "%.2f" % value


func _on_slider(value: float, key: String) -> void:
	SettingsManager.set_setting(key, value)


func _add_checkbox(key: String, label_key: String) -> void:
	var button := CheckButton.new()
	button.text = Localization.t(label_key)
	button.button_pressed = bool(SettingsManager.get_setting(key))
	button.custom_minimum_size = Vector2(420, 34)
	button.add_theme_font_size_override("font_size", 18)
	button.toggled.connect(_on_checkbox.bind(key))
	content.add_child(button)


func _on_checkbox(value: bool, key: String) -> void:
	SettingsManager.set_setting(key, value)


func _add_choice(key: String, label_key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(Localization.t(label_key), 18)
	name_label.custom_minimum_size = Vector2(320, 34)
	row.add_child(name_label)
	var option_button := OptionButton.new()
	for option in options:
		option_button.add_item(Localization.t(option))
	option_button.selected = int(SettingsManager.get_setting(key))
	option_button.custom_minimum_size = Vector2(280, 34)
	option_button.item_selected.connect(_on_choice.bind(key, options))
	row.add_child(option_button)
	content.add_child(row)


func _on_choice(index: int, key: String, options: Array) -> void:
	SettingsManager.set_setting(key, index)


# ---- tabs ------------------------------------------------------------------

func _build_audio() -> void:
	_add_header("settings_audio_hint")
	_add_slider("volume_master", "volume_master", 0.0, 1.0, 0.01)
	_add_slider("volume_music", "volume_music", 0.0, 1.0, 0.01)
	_add_slider("volume_sfx", "volume_sfx", 0.0, 1.0, 0.01)
	_add_slider("volume_ambient", "volume_ambient", 0.0, 1.0, 0.01)
	_add_slider("volume_voice", "volume_voice", 0.0, 1.0, 0.01)
	_add_checkbox("music_enabled", "music_enabled")
	_add_checkbox("sfx_enabled", "sfx_enabled")


func _build_accessibility() -> void:
	_add_header("settings_accessibility_hint")
	_add_choice("blood_level", "blood_level", ["blood_low", "blood_medium", "blood_full"])
	_add_checkbox("flash_effects", "flash_effects")
	_add_checkbox("screen_shake", "screen_shake")
	_add_checkbox("noise_indicators", "noise_indicators")
	_add_checkbox("subtitles", "subtitles")
	_add_slider("subtitle_size", "subtitle_size", 12.0, 30.0, 1.0)
	_add_choice("colorblind_mode", "colorblind_mode", ["colorblind_none", "colorblind_deuter", "colorblind_prot", "colorblind_trit"])
	_add_checkbox("high_contrast", "high_contrast")
	_add_checkbox("chat_text", "chat_text")
	_add_checkbox("voice_chat", "voice_chat")


func _build_camera() -> void:
	_add_header("settings_camera_hint")
	_add_slider("camera_zoom", "camera_zoom", 0.6, 1.8, 0.01)
	_add_slider("camera_lag", "camera_lag", 0.03, 0.5, 0.01)
	_add_checkbox("camera_follow", "camera_follow")
	_add_checkbox("show_fps", "show_fps")


func _build_interface() -> void:
	_add_header("settings_interface_hint")
	_add_slider("ui_scale", "ui_scale", 0.7, 1.6, 0.01)
	_add_choice("language", "language", ["language_ru", "language_en"])
	var apply := Button.new()
	apply.text = Localization.t("apply_language")
	apply.custom_minimum_size = Vector2(220, 40)
	apply.pressed.connect(_on_language)
	content.add_child(apply)


func _on_language() -> void:
	var index := int(SettingsManager.get_setting("language"))
	Localization.set_language("ru" if index == 0 else "en")
	SettingsManager.set_setting("language", index)
	status_label.text = Localization.t("language_applied")


func _add_header(key: String) -> void:
	var label := _label(Localization.t(key), 17)
	label.modulate = Color(0.55, 0.75, 0.85)
	content.add_child(label)


func _on_back() -> void:
	AudioManager.ui_click()
	back_requested.emit()
