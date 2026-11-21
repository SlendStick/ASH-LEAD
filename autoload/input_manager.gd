extends Node
## Input actions: defaults are created here, rebinding is persisted to
## user://input.json. Keeping bindings in code avoids fragile project.godot
## binary-ish input entries and makes remapping straightforward.

const INPUT_PATH := "user://input.json"

# action -> Array[InputEvent]
var bindings: Dictionary = {}
var _defaults: Dictionary = {}


func _ready() -> void:
	_build_defaults()
	load_bindings()
	_apply_all()


func _build_defaults() -> void:
	_defaults = {
		"move_up": [mk_key(KEY_W), mk_key(KEY_UP)],
		"move_down": [mk_key(KEY_S), mk_key(KEY_DOWN)],
		"move_left": [mk_key(KEY_A), mk_key(KEY_LEFT)],
		"move_right": [mk_key(KEY_D), mk_key(KEY_RIGHT)],
		"fire": [mk_mouse(MOUSE_BUTTON_LEFT)],
		"alt_fire": [mk_mouse(MOUSE_BUTTON_RIGHT)],
		"sprint": [mk_key(KEY_SHIFT)],
		"crouch": [mk_key(KEY_CTRL)],
		"interact": [mk_key(KEY_E)],
		"reload": [mk_key(KEY_R)],
		"order_wheel": [mk_key(KEY_G)],
		"ping": [mk_key(KEY_Q)],
		"scoreboard": [mk_key(KEY_TAB)],
		"pause": [mk_key(KEY_ESCAPE)],
		"slot1": [mk_key(KEY_1)],
		"slot2": [mk_key(KEY_2)],
		"slot3": [mk_key(KEY_3)],
		"gadget": [mk_key(KEY_4), mk_key(KEY_F)],
		"melee": [mk_key(KEY_V)],
		"map": [mk_key(KEY_M)],
		"chat": [mk_key(KEY_ENTER)],
		"team_chat": [mk_key(KEY_Y)],
	}
	for action in _defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)


func mk_key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


func mk_mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


func _apply_all() -> void:
	for action in _defaults:
		_apply_action(action)


func _apply_action(action: String) -> void:
	InputMap.action_erase_events(action)
	var events: Array = bindings.get(action, _defaults[action])
	for ev in events:
		InputMap.action_add_event(action, ev)


func set_binding(action: String, event: InputEvent) -> void:
	if not _defaults.has(action):
		return
	var list: Array = bindings.get(action, _defaults[action]).duplicate()
	# Replace events of the same device/type class, keep others.
	var new_list: Array = []
	for ev in list:
		if not _same_family(ev, event):
			new_list.append(ev)
	new_list.append(event)
	if new_list.is_empty():
		new_list.append(event)
	bindings[action] = new_list
	_apply_action(action)
	save_bindings()


func reset_bindings() -> void:
	bindings = {}
	_apply_all()
	save_bindings()


func _same_family(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return true
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return true
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return true
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return true
	return false


func save_bindings() -> void:
	var out := {}
	for action in bindings:
		var arr := []
		for ev in bindings[action]:
			arr.append(_serialize_event(ev))
		out[action] = arr
	var f := FileAccess.open(INPUT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out))
	f.close()


func load_bindings() -> void:
	bindings = {}
	if not FileAccess.file_exists(INPUT_PATH):
		return
	var f := FileAccess.open(INPUT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	for action in parsed:
		if not _defaults.has(action):
			continue
		var arr: Array = parsed[action]
		var events := []
		for data in arr:
			var ev := _deserialize_event(data)
			if ev != null:
				events.append(ev)
		if not events.is_empty():
			bindings[action] = events


func _serialize_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "code": int(ev.physical_keycode)}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": int(ev.button_index)}
	if ev is InputEventJoypadButton:
		return {"type": "joykey", "button": int(ev.button_index)}
	return {}


func _deserialize_event(data: Variant) -> InputEvent:
	if not (data is Dictionary) or not data.has("type"):
		return null
	match String(data["type"]):
		"key":
			return mk_key(int(data.get("code", 0)))
		"mouse":
			return mk_mouse(int(data.get("button", 0)))
		"joykey":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(data.get("button", 0))
			return ev
	return null


func get_action_events(action: String) -> Array:
	return InputMap.action_get_events(action)


func is_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)
