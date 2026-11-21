class_name ActorPlayer
extends Actor
## Human-controlled combatant. Reads raw input, produces intents, and hands them
## to the same Actor logic the bots use. Also owns client-side "feel": camera
## shake, aim assist for gamepad, and the local-only HUD hooks.

var input_enabled := true
var dead_camera := false
var aim_world := Vector2.ZERO
var use_mouse_aim := true
var possession_mode := false
var last_fire_pressed := false


func _ready() -> void:
	super()
	is_bot = false
	visual.is_bot = false
	set_physics_process(true)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or dead:
		return
	if possession_mode:
		return
	if event is InputEventMouseMotion and Input.is_action_pressed("aim"):
		pass
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and not Input.is_action_pressed("aim"):
			pass
	if event.is_action_pressed("fire") and not dead:
		pass


func _physics_process(delta: float) -> void:
	if dead:
		return
	var world_node := world
	if world_node != null and bool(world_node.get("match_over")):
		move_dir = Vector2.ZERO
		return
	_read_input(delta)
	super(delta)


func _read_input(delta: float) -> void:
	if not input_enabled:
		move_dir = Vector2.ZERO
		return
	# In an online match the client only produces intents -- the host simulates.
	# Local prediction still runs so movement feels immediate, but firing and
	# interaction are decided by the host from our input packets.
	if world != null and bool(world.get("is_client")):
		_read_input_predict()
		return
	var mx := Input.get_axis("move_left", "move_right")
	var my := Input.get_axis("move_up", "move_down")
	var mv := Vector2(mx, my)
	if mv.length() > 1.0:
		mv = mv.normalized()
	if downed:
		move_dir = mv
		return
	if flash_timer > 0.0:
		mv *= 0.35
	move_dir = mv

	sprinting = Input.is_action_pressed("sprint") and mv.length() > 0.1
	crouching = Input.is_action_pressed("crouch")
	aiming = Input.is_action_pressed("aim")
	if sprinting and Input.is_action_pressed("fire"):
		sprinting = false

	# aim direction
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var mouse := get_global_mouse_position()
	if use_mouse_aim:
		var d := mouse - global_position
		if d.length() > 6.0:
			facing = d.angle()
	else:
		var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if stick.length() > 0.2:
			facing = stick.angle()

	# movement-based facing fallback when idle
	if mv.length() < 0.05 and use_mouse_aim:
		var dd := mouse - global_position
		if dd.length() > 6.0:
			facing = dd.angle()

	# fire -- auto weapons keep firing, semi-auto fires once per click
	var fire_down := Input.is_action_pressed("fire")
	var w := weapon_stats()
	var auto := bool(w.get("auto", false))
	var want_fire := false
	if auto:
		want_fire = fire_down
	else:
		want_fire = fire_down and not last_fire_pressed
	last_fire_pressed = fire_down
	if want_fire:
		try_fire(get_global_mouse_position())
	elif fire_down and mag <= 0 and reload_timer <= 0.0:
		start_reload()

	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("melee") and not aiming:
		switch_to("knife" if loadout.has("knife") else (loadout[0] if not loadout.is_empty() else ""))
	if Input.is_action_just_pressed("swap_weapon"):
		switch_weapon(1)
	if Input.is_action_just_pressed("gadget"):
		_use_quick_gadget()
	if Input.is_action_just_pressed("flashlight"):
		var f := not visual.gear.has("flashlight")
		if f:
			visual.gear.append("flashlight")
		else:
			visual.gear.erase("flashlight")
		visual.queue_redraw()

	# breath hold for accuracy (hold aim + not moving)
	if aiming and mv.length() < 0.1 and breath_cooldown <= 0.0 and breath_hold > 0.0:
		pass
	elif aiming and mv.length() < 0.1 and Input.is_action_pressed("crouch") and breath_cooldown <= 0.0:
		breath_hold = 3.0
		breath_cooldown = 5.0

	# interaction (hold E)
	if interact_target != null:
		tick_interact(delta, Input.is_action_pressed("interact"))
	else:
		var best := world.call("find_interactable", self) if world != null and world.has_method("find_interactable") else null
		if best != null:
			var info: Dictionary = best
			set_interact_target(info.get("node"), str(info.get("kind", "")), float(info.get("time", 1.0)))
			Signals.interact_prompt.emit(str(info.get("text", "")), true)
		else:
			Signals.interact_prompt.emit("", false)


## Lightweight local prediction: movement + facing only, no shots, no damage.
func _read_input_predict() -> void:
	var mx := Input.get_axis("move_left", "move_right")
	var my := Input.get_axis("move_up", "move_down")
	var mv := Vector2(mx, my)
	if mv.length() > 1.0:
		mv = mv.normalized()
	move_dir = mv
	sprinting = Input.is_action_pressed("sprint") and mv.length() > 0.1
	crouching = Input.is_action_pressed("crouch")
	aiming = Input.is_action_pressed("aim")
	var mouse := get_global_mouse_position()
	var d := mouse - global_position
	if d.length() > 6.0:
		facing = d.angle()
	# cosmetic prompt only: the host decides whether the interaction happens
	if interact_target == null and world != null and world.has_method("find_interactable"):
		var info: Variant = world.call("find_interactable", self)
		if info != null and info is Dictionary:
			set_interact_target(info["node"], str(info["kind"]), float(info["time"]))
			Signals.interact_prompt.emit(str(info["text"]), true)
		else:
			Signals.interact_prompt.emit("", false)
	elif interact_target != null:
		Signals.interact_prompt.emit("", not is_instance_valid(interact_target))


## `G` throws the first lethal/utility grenade in the kit; support items (medkit,
## drone, fortify, breach kit) are used at the feet -- they are not thrown at
## people, they are placed where you stand.
func _use_quick_gadget() -> void:
	var order := ["flashbang", "smoke", "grenade", "molotov", "remote_charge"]
	for g in order:
		if has_gadget(g):
			var target := get_global_mouse_position()
			var max_range := 520.0
			var to := target - global_position
			if to.length() > max_range:
				target = global_position + to.normalized() * max_range
			if throw_gadget(g, target):
				Signals.notify.emit("Бросок: " + str(Db.WEAPONS[g]["short"]), "info")
			return
	for support in ["medkit", "drone", "fortify", "breach_kit"]:
		if has_gadget(support):
			var w: Dictionary = Db.WEAPONS[support]
			var spot := global_position + Vector2(cos(facing), sin(facing)) * 26.0
			world.call("spawn_thrown", spot, Vector2(cos(facing), sin(facing)), w, self, support)
			gadget_charges[support] = int(gadget_charges.get(support, 0)) - 1
			Signals.notify.emit("Установлено: " + str(w.get("short", support)), "good")
			return
	Signals.notify.emit("Гаджетов нет", "warning")
