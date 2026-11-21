class_name ThrownObject
extends Node2D
## Grenades, flashbangs, smoke, molotovs, remote charges, C4, drills, keycards,
## medkits, drones. Handles the physics arc, the fuse, the detonation effect and
## (for objective gadgets) the "installed" state.

var kind := "grenade"
var weapon: Dictionary = {}
var owner_actor: Actor = null
var owner_team := 0
var vel := Vector2.ZERO
var fuse := 2.5
var alive := true
var world: Node = null
var map: GeneratedMap
var bounces := 0
var armed := false
var installed := false
var install_progress := 0.0
var tripwire_dir := Vector2.RIGHT
var spin := 0.0
var smoke_left := 0.0
var fire_left := 0.0
var drill_time := 0.0
var is_objective := false
var linked_objective: Node = null


func setup(kind_id: String, start: Vector2, direction: Vector2, w: Dictionary, by: Actor, speed: float) -> void:
	kind = kind_id
	weapon = w
	owner_actor = by
	owner_team = by.team if by != null else 0
	global_position = start
	pos = start
	vel = direction.normalized() * speed
	fuse = float(w.get("fuse", 2.4))
	if fuse <= 0.0 and bool(w.get("impact_fuse", false)):
		fuse = 0.35
	is_objective = bool(w.get("objective", false))
	z_index = 10


var pos := Vector2.ZERO


func _ready() -> void:
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	spin += delta * 6.0
	if is_objective and installed:
		_tick_installed(delta)
		return
	if not installed:
		pos += vel * delta
		vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
		if map != null:
			var c := map.world_to_cell(pos)
			var t := map.tile_at(c)
			if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_VOID or t == GeneratedMap.TK_CRATE or t == GeneratedMap.TK_WINDOW:
				var nx := map.tile_at(map.world_to_cell(pos - Vector2(vel.x * delta * 2.0, 0)))
				var ny := map.tile_at(map.world_to_cell(pos - Vector2(0, vel.y * delta * 2.0)))
				if nx == GeneratedMap.TK_WALL or nx == GeneratedMap.TK_VOID:
					vel.x = -vel.x * 0.4
					pos.x += vel.x * delta * 2.0
				if ny == GeneratedMap.TK_WALL or ny == GeneratedMap.TK_VOID:
					vel.y = -vel.y * 0.4
					pos.y += vel.y * delta * 2.0
				bounces += 1
				if kind in ["molotov", "grenade"] and bounces == 1:
					Sfx.play_at("ui_click", pos, -18.0, 0.6)
				# diversion perk: the clatter pulls AI from much further away
				if kind in ["grenade", "molotov", "remote_charge"] and owner_actor != null:
					var radius := Perks.diversion_radius(owner_actor)
					Signals.noise_made.emit(pos, radius, "impact", owner_team)
				if is_objective:
					# objectives stick where thrown if they land near their target
					vel = Vector2.ZERO
		global_position = pos
		fuse -= delta
		if fuse <= 0.0:
			_detonate()
	queue_redraw()


func _tick_installed(delta: float) -> void:
	if kind == "drill" or kind == "c4":
		drill_time += delta
	queue_redraw()


func _detonate() -> void:
	if not alive:
		return
	alive = false
	var w := weapon
	# support gadgets: they never explode, they change the battlefield
	if kind == "medkit":
		_apply_medkit()
		queue_free()
		return
	if kind == "fortify":
		if world != null and world.has_method("deploy_barricade"):
			world.call("deploy_barricade", pos, owner_team)
		queue_free()
		return
	if kind == "drone":
		if world != null and world.has_method("deploy_drone"):
			world.call("deploy_drone", pos, owner_team, owner_actor)
		queue_free()
		return
	if kind == "breach_kit":
		if world != null and world.has_method("breach_kit_used"):
			world.call("breach_kit_used", pos, owner_actor)
		queue_free()
		return
	if kind == "smoke":
		if world != null and world.has_method("spawn_smoke"):
			world.call("spawn_smoke", pos, float(w.get("smoke", 12.0)), float(w.get("blast", 180.0)))
		queue_free()
		return
	if kind == "flashbang":
		if world != null and world.has_method("flash_burst"):
			world.call("flash_burst", pos, float(w.get("flash", 3.0)), float(w.get("blast", 200.0)), owner_team, owner_actor)
		queue_free()
		return
	if kind == "molotov":
		if world != null and world.has_method("spawn_fire"):
			world.call("spawn_fire", pos, float(w.get("fire", 8.0)), float(w.get("blast", 130.0)))
		queue_free()
		return
	if kind == "remote_charge" and bool(w.get("tripwire", false)):
		if world != null and world.has_method("explode"):
			world.call("explode", pos, float(w.get("blast", 140.0)), float(w.get("blast_dmg", 140.0)), owner_actor, kind)
		queue_free()
		return
	if float(w.get("blast", 0.0)) > 0.0 and world != null and world.has_method("explode"):
		world.call("explode", pos, float(w.get("blast", 150.0)), float(w.get("blast_dmg", 120.0)), owner_actor, kind)
	queue_free()


## Medkit: heals the thrower's team in a small radius, revives downed allies.
func _apply_medkit() -> void:
	if world == null:
		return
	var healed := 0
	for a in world.call("actors_all"):
		if a == null or a.dead or a.team != owner_team:
			continue
		if a.global_position.distance_to(pos) > 90.0:
			continue
		if a.downed:
			a.revive_progress = 1.0
			a.downed = false
			a.hp = 45.0
			a.visual.downed = false
			a.visual.queue_redraw()
			healed += 1
		elif a.hp < a.max_hp:
			a.hp = minf(a.max_hp, a.hp + 100.0)
			healed += 1
	Signals.actor_healed.emit(owner_actor.a_id if owner_actor != null else 0, float(healed))
	if healed > 0:
		Signals.match_event.emit("МЕДПАКЕТ: %d" % healed, Color("2bff9a"), "heal")


func arm_installed() -> void:
	installed = true
	vel = Vector2.ZERO


func trigger_tripwire() -> void:
	if not alive:
		return
	_detonate()


func _draw() -> void:
	if kind == "smoke":
		draw_circle(Vector2.ZERO, 6.0, Color(0.6, 0.65, 0.7, 0.8))
		return
	if kind == "molotov":
		draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
		draw_rect(Rect2(-3, -7, 6, 14), Color(0.25, 0.35, 0.2), true)
		draw_circle(Vector2(0, -9), 3.0, Color(1.0, 0.5, 0.15, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if kind == "drill" or kind == "c4" or kind == "remote_charge":
		var col := Color(1, 0.3, 0.2) if kind != "c4" else Color(1, 0.25, 0.5)
		draw_rect(Rect2(-7, -5, 14, 10), Color(0.1, 0.1, 0.12), true)
		var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(Vector2(0, 0), 2.5, Color(col.r, col.g, col.b, blink))
		if kind == "drill":
			draw_line(Vector2(-14, -2), Vector2(-7, -2), Color(0.6, 0.6, 0.6), 2.0)
			draw_line(Vector2(-14, 2), Vector2(-7, 2), Color(0.6, 0.6, 0.6), 2.0)
		return
	draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
	draw_circle(Vector2.ZERO, 5.0, Color(0.15, 0.2, 0.15))
	draw_circle(Vector2.ZERO, 5.0, Color(0.4, 0.6, 0.3), false, 1.5)
	draw_circle(Vector2.ZERO, 1.8, Color(1.0, 0.4, 0.2, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
