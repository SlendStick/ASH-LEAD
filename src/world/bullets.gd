class_name Bullet
extends Node2D
## A projectile (fast-moving or slow like rockets/grenades/arrows).
## Travels in fixed substeps so it cannot tunnel through walls, resolves the
## first actor hit at the closest point, applies damage with falloff, penetration
## and headshot chance, and reports the impact to the world for decals, blood,
## shell casings, camera-shake and hitmarkers.

var pos := Vector2.ZERO
var dir := Vector2.RIGHT
var speed := 4200.0
var distance := 0.0
var max_distance := 2400.0
var weapon: Dictionary = {}
var weapon_id := ""
var shooter: Actor = null
var shooter_team := 0
var alive := true
var pierce_left := 0
var hit_ids: Array[int] = []
var world: Node = null
var trail: Array[Vector2] = []
var is_rocket := false
var blast_radius := 0.0
var blast_dmg := 0.0
var gravity_arc := false


func setup(p: Vector2, d: Vector2, w: Dictionary, by: Actor, spd: float) -> void:
	pos = p
	dir = d.normalized()
	weapon = w
	weapon_id = by.current_weapon if by != null else ""
	speed = spd
	shooter = by
	shooter_team = by.team if by != null else 0
	if by != null:
		var idx := by.loadout.find(by.current_weapon)
		if idx >= 0:
			weapon_id = by.current_weapon
	pierce_left = int(w.get("penetration", 0.0) * 2.0)
	var kind := str(w.get("kind", "pistol"))
	max_distance = float(w.get("range", 1200.0)) * 1.6
	is_rocket = kind == "special" and float(w.get("blast", 0.0)) > 0.0
	blast_radius = float(w.get("blast", 0.0))
	blast_dmg = float(w.get("blast_dmg", 0.0))
	z_index = 30
	global_position = pos


func _ready() -> void:
	global_position = pos
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var step_len := speed * delta
	var remaining := step_len
	var guard := 0
	while remaining > 0.01 and alive and guard < 12:
		guard += 1
		var sub := minf(remaining, 34.0)
		remaining -= sub
		var prev := pos
		pos += dir * sub
		distance += sub
		# world collision
		if world != null and world.has_method("bullet_blocked"):
			var hit: Variant = world.call("bullet_blocked", prev, pos)
			if hit != null:
				_impact(Vector2(hit), true)
				return
		# actor collision: closest actor along the segment
		var victim: Actor = null
		var victim_d := 1e9
		if world != null and world.has_method("actors_all"):
			for a: Actor in world.call("actors_all"):
				if a == null or a.dead or a == shooter:
					continue
				if hit_ids.has(a.a_id):
					continue
				if a.team == shooter_team and not bool(GameFlow.match_config.get("friendly_fire", false)):
					continue
				var dist_to_line := _segment_circle(prev, pos, a.global_position, 17.0)
				if dist_to_line > 0.0 and dist_to_line < victim_d:
					victim_d = dist_to_line
					victim = a
		if victim != null:
			_hit_actor(victim)
			if not alive:
				return
		if distance > max_distance:
			alive = false
			global_position = pos
			queue_redraw()
			_despawn_soon()
			return
	global_position = pos
	trail.append(pos)
	if trail.size() > 4:
		trail.pop_front()
	queue_redraw()
	if is_rocket and distance > 20.0 and world != null and world.has_method("rocket_smoke"):
		world.call("rocket_smoke", pos, dir)


func _segment_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(0.001, ab.length_squared()), 0.0, 1.0)
	var closest := a + ab * t
	var d := closest.distance_to(c)
	if d <= r:
		return a.distance_to(closest) + 0.001
	return -1.0


func _hit_actor(victim: Actor) -> void:
	var w := weapon
	var base := float(w.get("dmg", 20.0))
	var falloff := float(w.get("falloff", 0.8))
	var eff := float(w.get("range", 900.0))
	var mult := 1.0
	if distance > eff:
		mult = pow(falloff, (distance - eff) / 120.0)
	var headshot := false
	# headshots: chance based on aim quality + slight randomness, or precise sniper
	var kind := str(w.get("kind", "pistol"))
	var head_chance := 0.10 + float(w.get("head", 2.0)) * 0.03
	if kind == "sniper":
		head_chance = 0.3
	if shooter != null and shooter.aiming:
		head_chance += 0.06
	if randf() < head_chance:
		headshot = true
		mult *= float(w.get("head", 2.2))
	var dmg := base * mult
	victim.take_damage(dmg, shooter, "bullet", dir, headshot)
	hit_ids.append(victim.a_id)
	if world != null:
		if world.has_method("hit_feedback"):
			world.call("hit_feedback", victim, dmg, headshot, shooter)
		if world.has_method("blood_burst"):
			world.call("blood_burst", pos, dir, 0.6 + dmg / 120.0)
		if world.has_method("add_bullet_hole") and randf() < 0.5:
			world.call("add_bullet_hole", pos, -dir)
	# slow / stun effects from special ammo
	if float(w.get("stun", 0.0)) > 0.0:
		victim.apply_stun(float(w.get("stun", 0.0)))
	if bool(w.get("silent_kill", false)) and headshot:
		pass
	if pierce_left > 0:
		pierce_left -= 1
		return
	alive = false
	_impact(pos, false)
	_despawn_soon()


func _impact(at: Vector2, wall: bool) -> void:
	alive = false
	if world != null:
		if world.has_method("impact_fx"):
			world.call("impact_fx", at, -dir, "wall" if wall else "flesh")
		if wall and world.has_method("add_bullet_hole"):
			world.call("add_bullet_hole", at, -dir)
	if is_rocket and blast_radius > 0.0:
		if world != null and world.has_method("explode"):
			world.call("explode", at, blast_radius, blast_dmg, shooter, weapon_id)
	queue_redraw()
	_despawn_soon()


func _despawn_soon() -> void:
	set_physics_process(false)
	var t := get_tree().create_timer(0.06)
	t.timeout.connect(queue_free)


func _draw() -> void:
	var col := Color(1.0, 0.85, 0.45)
	if weapon.get("suppressed", false):
		col = Color(0.7, 0.85, 1.0)
	var local_end := trail[0] - global_position if trail.size() > 0 else Vector2.ZERO
	if is_rocket:
		draw_circle(Vector2.ZERO, 4.0, Color(1, 0.6, 0.2))
		draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 0.8))
		return
	var start := Vector2.ZERO
	var end := -dir * 26.0
	draw_line(end, start, Color(col.r, col.g, col.b, 0.25), 3.0)
	draw_line(end * 0.4, start, col, 1.6)
	draw_circle(start, 1.6, Color(1, 1, 1, 0.9))
