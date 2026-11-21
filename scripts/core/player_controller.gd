class_name PlayerController
extends Node
## Keyboard/mouse (+ gamepad) input for the locally controlled character.

var character: Character
var match_ref: Match
var order_wheel_open: bool = false
var scoreboard_open: bool = false
var map_open: bool = false


func _process(delta: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	if not character.alive or character.downed:
		character.move_input = Vector2.ZERO
		character.want_fire = false
		return
	_read_movement()
	_read_aim()
	_read_actions()
	if match_ref != null and (match_ref.paused or match_ref.ui_blocking):
		character.move_input = Vector2.ZERO
		character.want_fire = false


func _read_movement() -> void:
	var dir := Vector2.ZERO
	if Input.get_connected_joypads().is_empty():
		dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	else:
		dir.x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		dir.y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		if dir.length() < 0.18:
			dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
			dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	character.move_input = dir.limit_length(1.0)
	character.want_sprint = Input.is_action_pressed("sprint") or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	if Input.is_action_just_pressed("crouch") or Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		character.want_crouch = not character.want_crouch


func _read_aim() -> void:
	character.aiming = Input.is_action_pressed("alt_fire") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_STICK)
	if not Input.get_connected_joypads().is_empty():
		var aim := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if aim.length() > 0.35:
			character.aim_target = character.global_position + aim.normalized() * 420.0
			return
	if match_ref != null:
		character.aim_target = match_ref.get_mouse_world()


func _read_actions() -> void:
	character.want_fire = Input.is_action_pressed("fire") or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_STICK)
	character.want_interact = Input.is_action_pressed("interact") or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	if Input.is_action_just_pressed("reload") or Input.is_joy_button_pressed(0, JOY_BUTTON_X):
		character.want_reload = true
	if Input.is_action_just_pressed("gadget"):
		character.want_gadget = true
	if Input.is_action_just_pressed("melee"):
		character.want_melee = true
	if Input.is_action_just_pressed("slot1"):
		character.want_slot = 0
	if Input.is_action_just_pressed("slot2"):
		character.want_slot = 1
	if Input.is_action_just_pressed("slot3"):
		character.want_slot = 2
	if Input.is_action_just_pressed("order_wheel"):
		if match_ref != null:
			match_ref.order_wheel_requested.emit()
	if Input.is_action_just_pressed("ping"):
		if match_ref != null:
			match_ref.ping(match_ref.get_mouse_world())
	if Input.is_action_just_pressed("scoreboard"):
		if match_ref != null:
			match_ref.scoreboard_requested.emit()
	if Input.is_action_just_pressed("map"):
		if match_ref != null:
			match_ref.map_requested.emit()
	if Input.is_action_just_pressed("pause"):
		if match_ref != null:
			match_ref.toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			character.cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			character.cycle_weapon(-1)
