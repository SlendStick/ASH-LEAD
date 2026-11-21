class_name Door
extends Node2D
## A door: swings open, can be locked, kicked, shot through, blown up or breached.
## Doors are the most important tactical objects in the game -- every fight in a
## Hotline Miami corridor starts with one.

var door_id := 0
var map: GeneratedMap
var cell: Vector2i
var open := true
var locked := false
var hp := 100.0
var map_visual: MapVisual
var world: Node
var swing := 0.0
var kind := "interior"
var breach_timer := 0.0
var noise_on_open := true
var alarm_triggered := false

## tile size in pixels (mirrors GeneratedMap.TILE; class consts are not const-expressions)
const T := 64


func setup(m: GeneratedMap, d: Dictionary, gid: int, visual: MapVisual, w: Node) -> void:
	map = m
	cell = d["cell"]
	open = bool(d.get("open", true))
	locked = bool(d.get("locked", false))
	hp = float(d.get("hp", 90.0))
	kind = str(d.get("kind", "interior"))
	door_id = gid
	map_visual = visual
	world = w
	global_position = Vector2(cell) * T + Vector2(T, T) * 0.5
	swing = 0.0 if open else 1.0
	z_index = 5
	_update_collision()


## The client rebuilt the map under us: keep the door state, point at the new grid.
func rebind_map(m: GeneratedMap) -> void:
	map = m
	global_position = Vector2(cell) * T + Vector2(T, T) * 0.5
	_update_collision()


## When true a *locked* door seals its grid tile (walls/LOS/pathing all read the
## grid, so one virtual wall is enough). Unlocked doors stay walkable.
var physics_blocking := true
var _block_cell := Vector2i(-9999, -9999)
var _blocked := false


func _ready() -> void:
	set_physics_process(false)


## A locked door blocks its tile in the map grid itself (doors sit on floor
## tiles that would otherwise be walkable). Walking, AI pathing, bullets and line
## of sight all read the same grid, so one virtual wall is enough.
func _update_collision() -> void:
	if map == null or not physics_blocking:
		return
	var need := locked and not open
	if need and not _blocked:
		_block_cell = map.world_to_cell(global_position)
		var t := map.tile_at(_block_cell)
		if t == GeneratedMap.TK_FLOOR or t == GeneratedMap.TK_DOOR:
			if map_visual != null:
				map_visual.set_tile_solid(_block_cell, true)
			else:
				map.set_tile_cell(_block_cell, GeneratedMap.TK_WALL)
			_blocked = true
	elif not need and _blocked:
		if map.tile_at(_block_cell) == GeneratedMap.TK_WALL:
			if map_visual != null:
				map_visual.set_tile_solid(_block_cell, false)
			else:
				map.set_tile_cell(_block_cell, GeneratedMap.TK_DOOR)
		_blocked = false


func _draw() -> void:
	var horizontal := map != null and (map.tile_at(cell + Vector2i(1, 0)) == GeneratedMap.TK_FLOOR or map.tile_at(cell + Vector2i(-1, 0)) == GeneratedMap.TK_FLOOR)
	var thick := 10.0
	var length := T - 8.0
	var col := Color(0.1686, 0.1333, 0.098) if kind != "service" else Color(0.1137, 0.1647, 0.1333)
	if kind == "vault" or locked:
		col = Color(0.1686, 0.1843, 0.2275)
	var swing_angle := swing * (PI * 0.55)
	draw_set_transform(Vector2.ZERO, swing_angle, Vector2.ONE)
	if horizontal:
		draw_rect(Rect2(-length * 0.5, -thick * 0.5, length, thick), col, true)
		draw_rect(Rect2(-length * 0.5, -thick * 0.5, length, thick), col.lightened(0.3), false, 1.5)
		draw_circle(Vector2(length * 0.4, 0), 2.5, Color(1.0, 0.6902, 0.1686))
	else:
		draw_rect(Rect2(-thick * 0.5, -length * 0.5, thick, length), col, true)
		draw_rect(Rect2(-thick * 0.5, -length * 0.5, thick, length), col.lightened(0.3), false, 1.5)
		draw_circle(Vector2(0, length * 0.4), 2.5, Color(1.0, 0.6902, 0.1686))
	if locked:
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.1686, 0.3843))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func toggle(by: Actor = null) -> bool:
	if locked:
		Sfx.play_at("door_locked", global_position, -8.0)
		Signals.noise_made.emit(global_position, 320.0, "door", by.team if by != null else 2)
		if by != null:
			Signals.interact_prompt.emit("Заперто. Нужен лом или наглость.", true)
		return false
	open = not open
	swing = 0.0 if open else 1.0
	Sfx.play_at("door_open", global_position, -8.0, randf_range(0.9, 1.1))
	if noise_on_open:
		# burglar opens doors at half volume: the radius the AI hears shrinks too,
		# and opening it by hand stops the loud clack
		var radius := (480.0 if open else 420.0) * (0.5 if Perks.quiet_breach(by) else 1.0)
		Signals.noise_made.emit(global_position, radius, "door", by.team if by != null else 2)
	Signals.door_state.emit(door_id, open, locked)
	_update_collision()
	queue_redraw()
	return true


func kick(by: Actor) -> void:
	if not locked and open:
		return
	open = true
	locked = false
	swing = 0.0
	Sfx.play_at("door_locked", global_position, -2.0, 0.7)
	# a burglar pops the lock instead of kicking it in
	var kick_radius := 900.0
	if Perks.quiet_breach(by):
		kick_radius = 300.0
	Signals.noise_made.emit(global_position, kick_radius, "door", by.team if by != null else 2)
	# stun whoever is behind it
	if world != null and world.has_method("stun_cone"):
		var stun := 1.2 + Perks.kick_stun(by)
		world.call("stun_cone", global_position, 90.0 if stun <= 1.2 else 130.0, stun, by.team)
	_update_collision()
	queue_redraw()


func shoot_through(damage: float) -> void:
	hp -= damage
	if hp <= 0.0:
		breach()


func breach() -> void:
	open = true
	locked = false
	swing = 0.2
	hp = 0.0
	Sfx.play_at("door_locked", global_position, 0.0, 0.6)
	Signals.noise_made.emit(global_position, 1200.0, "door", Db.TEAM_CRIMINAL)
	if world != null and world.has_method("door_breached"):
		world.call("door_breached", self)
	_update_collision()
	queue_redraw()


func interact(by: Actor) -> void:
	if locked:
		kick(by)
	else:
		toggle(by)


func set_locked(v: bool) -> void:
	locked = v
	if locked:
		open = false
		swing = 1.0
	_update_collision()
	queue_redraw()
