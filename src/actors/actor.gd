class_name Actor
extends CharacterBody2D
## Base combatant: a player, a bot, or a civilian.
##
## Owns health, stamina, posture, weapons, inventory, interaction, stealth state,
## downed/revive, death and the per-tick movement that feeds the vision system.
## Gameplay decisions live in ActorPlayer (input) and BotBrain (AI); this class
## only executes intents, so bots and players obey exactly the same rules.

signal died(actor: Actor, killer: Actor)
signal damaged(actor: Actor, amount: float, source: Actor, kind: String)
signal downed_changed(actor: Actor, is_downed: bool)
signal interacted(actor: Actor, target_id: int, kind: String)

const SPEED_WALK := 205.0
const SPEED_SPRINT := 348.0
const SPEED_CROUCH := 108.0
const SPEED_AIM := 118.0
const SPEED_DOWNED := 34.0

var a_id := 0
var a_name := "ACTOR"
var team := Db.TEAM_CRIMINAL
var is_bot := false
var is_civilian := false
var is_hostage := false
## Perk ids owned by this actor (see src/actors/perks.gd for the numbers).
var perks: Array[String] = []
var is_local_player := false

# --- vital stats -----------------------------------------------------------
var max_hp := 100.0
var hp := 100.0
var armor := 0.0
var max_armor := 0.0
var stamina := 100.0
var bleed := 0.0
var downed := false
var downed_timer := 0.0
var dead := false
var revive_progress := 0.0
var revived_count := 0

# --- movement --------------------------------------------------------------
var facing := 0.0
var move_dir := Vector2.ZERO
var sprinting := false
var crouching := false
var aiming := false
var speed_mult := 1.0
var slow_timer := 0.0
var stun_timer := 0.0
var flash_timer := 0.0
var last_noise_timer := 0.0
var step_accum := 0.0
var on_wet := false

# --- posture / stealth -----------------------------------------------------
var concealment := 0.0        ## 0..1, how hidden this actor is right now
var in_light := 0.0          ## 0..1 light level at actor position
var in_shadow := false
var spotted_by := {}         ## team bitmask-ish: {team: last_seen_time}
var visible_to := {}         ## {team: bool} last frame visibility
var last_seen_pos := {}      ## {team: Vector2}
var last_seen_time := {}     ## {team: float}
var noise_level := 0.0
var alertness := 0.0
var investigate_point := Vector2.ZERO
var investigate_time := 0.0

# --- weapons ---------------------------------------------------------------
var loadout: Array[String] = []
var weapon_index := 0
var current_weapon := ""
var mag := 0
var reserve := 0
var fire_cooldown := 0.0
var reload_timer := 0.0
var draw_timer := 0.0
var recoil_heat := 0.0
var breath_hold := 0.0
var breath_cooldown := 0.0
var gadget_charges := {"grenade": 0, "flashbang": 0, "smoke": 0, "molotov": 0, "remote_charge": 0}
var bag_carried := false
var hostage_carried: Node = null
var arrest_target: Node = null
var is_arresting := false
var arrest_progress := 0.0

# --- interaction -----------------------------------------------------------
var interact_target: Node = null
var interact_kind := ""
var interact_time := 0.0
var interact_hold := 0.0

# --- visuals / references --------------------------------------------------
var visual: ActorVisual
var body_shape: CollisionShape2D
var map: GeneratedMap
var world: Node = null
var ai: Node = null
var muzzle_pos: Vector2 = Vector2.ZERO
var anim_clock := 0.0
var skin_outfit := "heist"

# --- combat statistics -----------------------------------------------------
var kills := 0
var deaths := 0
var assists := 0
var headshots := 0
var score := 0
var money := 0
var last_damage_time := 0.0
var last_attacker: Actor = null
var kill_streak := 0
var revenge_target := 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	body_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15.0
	body_shape.shape = shape
	add_child(body_shape)
	visual = ActorVisual.new()
	visual.name = "Visual"
	add_child(visual)
	set_physics_process(true)


func configure(id: int, actor_name: String, team_id: int, bot: bool) -> void:
	a_id = id
	a_name = actor_name
	team = team_id
	is_bot = bot
	visual.team = team_id
	visual.is_bot = bot
	visual.queue_redraw()


func set_outfit(outfit: String) -> void:
	skin_outfit = outfit
	visual.setup(team, outfit)


func setup_stats(perk_ids: Array = []) -> void:
	perks.clear()
	for p in perk_ids:
		if str(p) != "":
			perks.append(str(p))
	max_hp = 100.0
	if perks.has("vigor"):
		max_hp += 25.0
	hp = max_hp
	stamina = 100.0
	armor = 0.0
	max_armor = 0.0


func give_armor(armor_id: String) -> void:
	var a: Dictionary = Db.ARMOR.get(armor_id, Db.ARMOR["none"])
	max_armor = float(a.get("hp", 0.0))
	armor = max_armor
	speed_mult = float(a.get("speed", 1.0))


func equip_weapon(weapon_id: String) -> void:
	if not Db.WEAPONS.has(weapon_id):
		return
	current_weapon = weapon_id
	visual.weapon_id = weapon_id
	var w: Dictionary = Db.WEAPONS[weapon_id]
	mag = int(w.get("mag", 1))
	reserve = int(w.get("reserve", 0))
	visual.suppressed = bool(w.get("suppressed", false))
	draw_timer = float(w.get("draw", 0.25))
	reload_timer = 0.0
	fire_cooldown = 0.0
	visual.queue_redraw()


func add_weapon(weapon_id: String) -> void:
	if not loadout.has(weapon_id):
		loadout.append(weapon_id)


func weapon_stats() -> Dictionary:
	return Db.WEAPONS.get(current_weapon, Db.WEAPONS["pm9"])


func current_accuracy_spread() -> float:
	var w := weapon_stats()
	var spread := float(w.get("spread", 1.5))
	var move_speed := move_dir.length()
	spread += float(w.get("move_spread", 3.0)) * move_speed * (0.4 if crouching else 1.0)
	spread += recoil_heat * 1.6
	if aiming:
		spread *= 0.62
	if crouching:
		spread *= 0.78
	if breath_hold > 0.0:
		spread *= 0.66 * Perks.breath_spread_mult(self)
	if aiming:
		spread *= Perks.aim_spread_mult(self)
	if sprinting:
		spread *= 1.4
	return maxf(0.08, spread)


func can_fire() -> bool:
	if dead or downed or reload_timer > 0.0 or draw_timer > 0.0 or fire_cooldown > 0.0:
		return false
	if stun_timer > 0.0 or is_arresting:
		return false
	if mag <= 0:
		return false
	var w := weapon_stats()
	if str(w.get("kind", "")) == "melee":
		return true
	return true


# ---------------------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	anim_clock += delta
	_tick_timers(delta)
	_tick_movement(delta)
	_tick_posture(delta)
	_tick_visuals(delta)
	_tick_bleed(delta)


func _tick_timers(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	reload_timer = maxf(0.0, reload_timer - delta)
	draw_timer = maxf(0.0, draw_timer - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	breath_cooldown = maxf(0.0, breath_cooldown - delta * Perks.breath_recover_mult(self))
	recoil_heat = maxf(0.0, recoil_heat - delta * 2.2)
	last_noise_timer = maxf(0.0, last_noise_timer - delta)
	last_damage_time += delta
	if breath_hold > 0.0:
		breath_hold = maxf(0.0, breath_hold - delta)
	if downed:
		downed_timer += delta
		if downed_timer > 34.0:
			die(last_attacker, true)
		if move_dir.length() > 0.2:
			hp = maxf(0.0, hp - delta * 1.5)
	if reload_timer > 0.0 and reload_timer < 0.06 and mag <= 0:
		_finish_reload()


func _tick_movement(delta: float) -> void:
	if downed:
		var crawl := move_dir * SPEED_DOWNED
		velocity = crawl
		move_and_slide()
		return
	if stun_timer > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		return
	var target_speed := SPEED_WALK
	if aiming:
		target_speed = SPEED_AIM
	elif crouching:
		target_speed = SPEED_CROUCH
	elif sprinting and stamina > 4.0 and move_dir.length() > 0.1:
		target_speed = SPEED_SPRINT * Perks.sprint_mult(self)
	var mult := speed_mult
	if slow_timer > 0.0:
		mult *= 0.62
	if bag_carried:
		mult *= 0.78
	if hostage_carried != null:
		mult *= 0.6
	if bleed > 20.0:
		mult *= 0.9 * Perks.bleed_mult(self)
	velocity = velocity.move_toward(move_dir * target_speed * mult, 1900.0 * delta)
	move_and_slide()

	# stamina
	if sprinting and move_dir.length() > 0.1:
		stamina = maxf(0.0, stamina - delta * 21.0 * Perks.stamina_drain_mult(self))
	else:
		stamina = minf(100.0, stamina + delta * 15.5)

	# footsteps & noise: sprint = loud, crouch = silent
	var spd: float = velocity.length()
	on_wet = _is_wet_ground()
	if spd > 12.0:
		step_accum += delta * (spd / 60.0)
		var step_threshold := 2.6 if crouching else (1.7 if sprinting else 2.1)
		if step_accum > step_threshold:
			step_accum = 0.0
			_do_step(spd)
	else:
		step_accum = 0.0


func _is_wet_ground() -> bool:
	if map == null:
		return false
	var c := map.world_to_cell(global_position)
	return map.tile_at(c) == GeneratedMap.TK_WATER


func _do_step(spd: float) -> void:
	var radius := 260.0
	var loud := 0.5
	if crouching:
		radius = 70.0
		loud = 0.12
	elif sprinting:
		radius = 640.0
		loud = 1.0
	elif aiming:
		radius = 160.0
		loud = 0.3
	if on_wet:
		radius *= 1.4
		Sfx.step(global_position, true, true)
	else:
		Sfx.step(global_position, sprinting, false)
	noise_level = loud
	radius *= Perks.footstep_noise_mult(self)
	Signals.noise_made.emit(global_position, radius, "step", team)


func _tick_posture(delta: float) -> void:
	# stealth: light level, stance, movement speed => concealment
	var light := 0.0
	if world != null and world.has_method("light_at"):
		light = float(world.call("light_at", global_position))
	in_light = light
	in_shadow = light < 0.22
	var c := Perks.concealment_bonus(self)
	if crouching:
		c += 0.34
	if aiming:
		c += 0.12
	if velocity.length() < 16.0:
		c += 0.28
	else:
		c -= minf(0.4, velocity.length() / 900.0)
	c += (1.0 - clampf(light, 0.0, 1.0)) * 0.55
	if current_weapon != "":
		c -= 0.05
	if sprinting:
		c -= 0.25
	concealment = clampf(c, 0.0, 1.0)
	visual.crouching = crouching
	visual.aiming = aiming
	visual.moving = velocity.length() > 20.0
	visual.downed = downed
	visual.carrying_bag = bag_carried
	visual.carrying_hostage = hostage_carried != null
	visual.visible = true


func _tick_visuals(delta: float) -> void:
	visual.rotation = facing
	visual.tick(delta)
	if not downed and not dead:
		visual.position = Vector2(0, -4.0 if crouching else 0.0)
	visual.visible = true


func _tick_bleed(delta: float) -> void:
	if bleed > 0.0 and not dead:
		if bleed > 8.0:
			hp -= delta * (bleed * 0.35)
			if hp <= 0.0:
				hp = 0.0
				die(last_attacker, false)
		bleed = maxf(0.0, bleed - delta * 4.5)


# ---------------------------------------------------------------------------
# COMBAT
# ---------------------------------------------------------------------------

func friendly_fire_on() -> bool:
	if world == null:
		return false
	if world.has_method("friendly_fire_enabled"):
		return bool(world.call("friendly_fire_enabled"))
	return bool(world.get("friendly_fire"))


func take_damage(amount: float, source: Actor, kind: String = "bullet", hit_dir: Vector2 = Vector2.ZERO, headshot: bool = false) -> void:
	if dead:
		return
	if team == Db.TEAM_CIVILIAN and source != null and source.team == Db.TEAM_CIVILIAN:
		return
	if source != null and source.team == team:
		if not friendly_fire_on():
			return
	var dmg := amount
	# armour soaks first, reduced effectiveness vs rifles
	if armor > 0.0:
		var absorbed := minf(armor, dmg * 0.62)
		armor -= absorbed
		dmg -= absorbed * 0.8
	hp -= dmg
	last_damage_time = 0.0
	if source != null and source.team != team:
		last_attacker = source
		last_seen_pos[source.team] = source.global_position
		last_seen_time[source.team] = anim_clock
		if visual != null:
			visual.add_blood_stain(hit_dir)
	# hit reactions
	if kind == "bullet":
		stun_timer = maxf(stun_timer, 0.06)
		if source != null and source.team != team:
			# being shot reveals the shooter's direction to the victim's team
			Signals.actor_spotted.emit(source.a_id, a_id, team)
	damaged.emit(self, amount, source, kind)
	if is_local_player:
		Signals.player_damaged.emit(dmg)
	if hp <= 0.0:
		hp = 0.0
		_enter_downed_or_die(source, headshot)


func _enter_downed_or_die(source: Actor, headshot: bool) -> void:
	var w_kind := "bullet"
	if headshot:
		die(source, false, headshot)
		return
	# Downed state: heist modes and non-headshot heavy damage allow revive.
	var allow_downed := team != Db.TEAM_CIVILIAN and (revived_count < 2) and not bool(GameFlow.match_config.get("instant_death", false))
	if allow_downed and randf() < 0.82:
		downed = true
		downed_timer = 0.0
		hp = 1.0
		downed_changed.emit(self, true)
		Signals.actor_downed.emit(a_id, source.a_id if source != null else 0)
		visual.downed = true
		visual.queue_redraw()
		if is_local_player:
			Ui.show_hint("Ты ранен. Если тебя не поднимут — всё.", 2.5)
		return
	die(source, false, headshot)


func die(killer: Actor, bled_out: bool = false, headshot: bool = false) -> void:
	if dead:
		return
	dead = true
	downed = false
	hp = 0.0
	velocity = Vector2.ZERO
	deaths += 1
	kill_streak = 0
	visual.dead = true
	visual.queue_redraw()
	collision_layer = 0
	collision_mask = 0
	if world != null and world.has_method("on_actor_died"):
		world.call("on_actor_died", self, killer, headshot, bled_out)
	died.emit(self, killer)
	if is_civilian:
		Sfx.scream(global_position)
	elif headshot:
		Sfx.scream(global_position, 2)
	_drop_weapon()


func _drop_weapon() -> void:
	if world != null and world.has_method("drop_weapon") and current_weapon != "" and current_weapon != "knife":
		world.call("drop_weapon", global_position, current_weapon, mag, reserve)


## Same contract as Door.interact: the interaction system calls interact(self)
## on whatever the prompt points at.
func interact(by: Actor) -> void:
	if by == null:
		return
	if downed:
		if world != null and world.has_method("revive_ally"):
			world.call("revive_ally", by, self)
		return
	if world != null:
		world.call("grab_civilian", by, self, false)


func revive(by: Actor) -> void:
	if not downed:
		return
	downed = false
	downed_timer = 0.0
	hp = minf(max_hp, max_hp * 0.45)
	revived_count += 1
	bleed = 0.0
	visual.downed = false
	visual.queue_redraw()
	downed_changed.emit(self, false)
	Signals.actor_revived.emit(a_id, by.a_id)


func arrest(by: Actor) -> void:
	if team != Db.TEAM_CRIMINAL:
		return
	downed = true
	downed_timer = 0.0
	hp = minf(hp, 35.0)
	visual.surrendering = true
	visual.downed = true
	visual.queue_redraw()
	Signals.hostage_state.emit(a_id, "arrested")
	Signals.notify.emit("%s задержан" % a_name, "good")


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func apply_stun(seconds: float) -> void:
	stun_timer = maxf(stun_timer, seconds)
	velocity = Vector2.ZERO


func apply_flash(seconds: float) -> void:
	flash_timer = maxf(flash_timer, seconds)
	stun_timer = maxf(stun_timer, seconds * 0.35)


func apply_slow(seconds: float) -> void:
	slow_timer = maxf(slow_timer, seconds)


# ---------------------------------------------------------------------------
# WEAPONS
# ---------------------------------------------------------------------------

func start_reload() -> void:
	if reload_timer > 0.0 or dead or downed:
		return
	var w := weapon_stats()
	if str(w.get("kind", "")) == "melee":
		return
	if mag >= int(w.get("mag", 1)) or reserve <= 0:
		return
	reload_timer = float(w.get("reload", 2.0))
	Sfx.play_at("reload", global_position, -6.0, randf_range(0.95, 1.05))
	Signals.noise_made.emit(global_position, 220.0, "reload", team)


func _finish_reload() -> void:
	var w := weapon_stats()
	var need := int(w.get("mag", 1)) - mag
	var take := mini(need, reserve)
	mag += take
	reserve -= take
	visual.queue_redraw()


func try_fire(target: Vector2) -> void:
	if not can_fire():
		if mag <= 0 and reload_timer <= 0.0:
			start_reload()
		return
	var w := weapon_stats()
	if str(w.get("kind", "")) == "melee":
		_melee_attack(w, target)
		return
	fire_cooldown = 60.0 / maxf(30.0, float(w.get("rpm", 400.0)))
	mag -= 1
	var spread := current_accuracy_spread()
	var base_angle := (target - global_position).angle()
	facing = base_angle
	var pellets := int(w.get("pellets", 1))
	var suppressed := bool(w.get("suppressed", false))
	for i in range(pellets):
		var jitter := deg_to_rad(spread) * randf_range(-0.5, 0.5)
		if pellets > 1:
			jitter = deg_to_rad(spread) * randf_range(-0.55, 0.55)
		var ang := base_angle + jitter
		var dir := Vector2(cos(ang), sin(ang))
		_shoot_projectile(w, dir, i)
	recoil_heat = minf(2.4, recoil_heat + float(w.get("recoil", 1.0)) * 0.16)
	visual.muzzle_flash()
	Sfx.gunshot(current_weapon, global_position, suppressed)
	Signals.shot_fired.emit(a_id, global_position, Vector2(cos(base_angle), sin(base_angle)), current_weapon)
	var loud := float(w.get("loud", 800.0))
	Signals.noise_made.emit(global_position, loud, "gunshot", team)
	if world != null and world.has_method("muzzle_light"):
		world.call("muzzle_light", muzzle_world(), not suppressed)
	if is_local_player and Util.screen_shake_multiplier() > 0.0:
		Signals.camera_shake.emit(float(w.get("kick", 0.2)) * Util.screen_shake_multiplier() * 3.2, 0.08)
	if mag <= 0:
		start_reload()


func muzzle_world() -> Vector2:
	return global_position + Vector2(cos(facing), sin(facing)) * 26.0


func _shoot_projectile(w: Dictionary, dir: Vector2, pellet_index: int) -> void:
	var speed := float(w.get("speed", 4200.0))
	var origin := muzzle_world()
	if world == null:
		return
	var bullet: Node2D
	if speed >= 2600.0:
		bullet = world.call("spawn_hitscan", origin, dir, w, self, 0.0) as Node2D
	else:
		bullet = world.call("spawn_projectile", origin, dir, w, self, speed) as Node2D
	if bullet == null:
		return
	if pellet_index == 0:
		Signals.shell_ejected.emit(global_position, dir.rotated(PI * 0.5))


func _melee_attack(w: Dictionary, target: Vector2) -> void:
	fire_cooldown = 60.0 / maxf(30.0, float(w.get("rpm", 120.0)))
	var reach := float(w.get("range", 70.0))
	var to := target - global_position
	var ang := to.angle()
	facing = ang
	visual.muzzle_flash()
	if current_weapon == "knife" or current_weapon == "taser":
		Sfx.play_at("knife" if current_weapon == "knife" else "shot_taser", global_position, -4.0)
	else:
		Sfx.play_at("punch", global_position, -4.0)
	Signals.noise_made.emit(global_position, float(w.get("loud", 300.0)), "melee", team)
	var hit_any := false
	if world != null and world.has("actors"):
		for other: Actor in world.call("actors_for_team", -1):
			if other == self or other.dead or other.is_civilian:
				continue
			if other.team == team and not friendly_fire_on():
				continue
			var d: float = other.global_position.distance_to(global_position)
			if d > reach + 10.0:
				continue
			var da := absf(wrapf((other.global_position - global_position).angle() - ang, -PI, PI))
			if da > 1.05:
				continue
			hit_any = true
			var back: bool = absf(wrapf(other.facing - ang, -PI, PI)) < 0.9 and other.velocity.length() < 40.0
			var is_exec: bool = bool(w.get("execute", false)) and back
			var mult := 2.4 if is_exec else 1.0
			var dmg := float(w.get("dmg", 40.0)) * mult
			if other.downed:
				dmg = 999.0
			other.take_damage(dmg, self, "melee", (other.global_position - global_position).normalized(), false)
			if bool(w.get("stun", 0.0) > 0.0):
				other.apply_stun(float(w.get("stun", 0.0)))
			if is_exec:
				Signals.notify.emit("ТИХОЕ ДОБИВАНИЕ", "good")
				if is_bot or GameFlow.profile.get("perks", []).has("predator"):
					heal(20.0)
			if world != null and world.has_method("blood_burst"):
				world.call("blood_burst", other.global_position, (other.global_position - global_position).normalized(), 1.4 if is_exec else 0.7)
			Sfx.play_at("flesh", other.global_position, -3.0)
	if not hit_any:
		# swing hits props and makes noise anyway
		Signals.noise_made.emit(global_position, 180.0, "swing", team)


# ---------------------------------------------------------------------------
# INTERACTION
# ---------------------------------------------------------------------------

func set_interact_target(target: Node, kind: String, time_needed: float) -> void:
	interact_target = target
	interact_kind = kind
	interact_time = time_needed
	interact_hold = 0.0


func clear_interact() -> void:
	interact_target = null
	interact_kind = ""


func tick_interact(delta: float, holding: bool) -> void:
	if interact_target == null:
		return
	if not holding or dead or downed:
		interact_hold = 0.0
		return
	interact_hold += delta
	if interact_hold >= interact_time:
		var t := interact_target
		var k := interact_kind
		interact_hold = 0.0
		if t != null and is_instance_valid(t) and t.has_method("interact"):
			t.call("interact", self)
		interacted.emit(self, 0, k)
		clear_interact()


func interact_progress() -> float:
	if interact_target == null or interact_time <= 0.0:
		return 0.0
	return clampf(interact_hold / interact_time, 0.0, 1.0)


# ---------------------------------------------------------------------------
# EQUIP / THROW
# ---------------------------------------------------------------------------

func switch_weapon(delta_index: int) -> void:
	if loadout.is_empty():
		return
	weapon_index = wrapi(weapon_index + delta_index, 0, loadout.size())
	equip_weapon(loadout[weapon_index])


func switch_to(weapon_id: String) -> void:
	var idx := loadout.find(weapon_id)
	if idx >= 0:
		weapon_index = idx
		equip_weapon(weapon_id)


func throw_gadget(gadget_id: String, target: Vector2) -> bool:
	if not gadget_charges.has(gadget_id) or int(gadget_charges.get(gadget_id, 0)) <= 0:
		return false
	if not Db.WEAPONS.has(gadget_id):
		return false
	var w: Dictionary = Db.WEAPONS[gadget_id]
	if bool(w.get("objective", false)) and gadget_id not in ["c4", "drill"]:
		return false
	if gadget_id in ["c4", "drill", "keycard"]:
		Signals.notify.emit("Это не бросается. Подойди к цели и нажми E.", "warning")
		return false
	gadget_charges[gadget_id] = int(gadget_charges[gadget_id]) - 1
	var dir := (target - global_position).normalized()
	facing = dir.angle()
	if world != null and world.has_method("spawn_thrown"):
		world.call("spawn_thrown", muzzle_world(), dir, w, self, gadget_id)
	Sfx.play_at("knife", global_position, -8.0, 0.8)
	return true


func has_gadget(gadget_id: String) -> bool:
	return int(gadget_charges.get(gadget_id, 0)) > 0


# ---------------------------------------------------------------------------
# SNAPSHOT (for network sync / bot possession)
# ---------------------------------------------------------------------------

func to_snapshot() -> Dictionary:
	return {
		"id": a_id, "n": a_name, "t": team, "p": [global_position.x, global_position.y],
		"f": facing, "hp": hp, "ar": armor, "d": downed, "dead": dead,
		"w": current_weapon, "mag": mag, "res": reserve, "bot": is_bot,
		"con": concealment, "bag": bag_carried, "civ": is_civilian, "k": kills,
	}


func apply_snapshot(d: Dictionary) -> void:
	var p: Array = d.get("p", [0, 0])
	global_position = global_position.lerp(Vector2(float(p[0]), float(p[1])), 0.5)
	facing = float(d.get("f", 0.0))
	hp = float(d.get("hp", 100.0))
	downed = bool(d.get("d", false))
	dead = bool(d.get("dead", false))
	current_weapon = str(d.get("w", ""))
	bag_carried = bool(d.get("bag", false))
	visual.dead = dead
	visual.downed = downed
	visual.weapon_id = current_weapon
