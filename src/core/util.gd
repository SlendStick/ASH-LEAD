class_name Util
extends RefCounted
## Small stateless helpers shared by gameplay, AI and UI.

## tile size in pixels (mirrors GeneratedMap.TILE; class consts are not const-expressions)
const T := 64


## Grid DDA line of sight. Returns true when the segment crosses no vision blocker.
static func los_clear(map: GeneratedMap, from: Vector2, to: Vector2, ignore_doors: bool = false) -> bool:
	if map == null:
		return true
	var delta := to - from
	var dist := delta.length()
	if dist < 1.0:
		return true
	var steps := int(dist / (T * 0.35)) + 1
	var prev := from
	for i in range(1, steps + 1):
		var p := from + delta * (float(i) / float(steps))
		var c := map.world_to_cell(p)
		var t := map.tile_at(c)
		if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_VOID:
			return false
		if t == GeneratedMap.TK_WINDOW:
			# glass blocks vision faintly but for AI it counts as partial; treat as block
			return false
		if not ignore_doors and t == GeneratedMap.TK_CRATE:
			return false
		prev = p
	return true


## Returns the first blocking point along a segment (for LOS checks with distance).
static func los_clear_fast(map: GeneratedMap, from: Vector2, to: Vector2) -> bool:
	if map == null:
		return true
	var delta := to - from
	var dist := delta.length()
	if dist < 1.0:
		return true
	var step := T * 0.5
	var steps := int(dist / step) + 2
	var inv := 1.0 / float(steps)
	for i in range(1, steps):
		var p := from + delta * (float(i) * inv)
		if map.opaque_at(map.world_to_cell(p)):
			return false
	return true


static func los_hit(map: GeneratedMap, from: Vector2, to: Vector2) -> float:
	if map == null:
		return -1.0
	var delta := to - from
	var dist := delta.length()
	if dist < 1.0:
		return -1.0
	var steps := int(dist / (T * 0.3)) + 1
	for i in range(1, steps + 1):
		var p := from + delta * (float(i) / float(steps))
		var c := map.world_to_cell(p)
		var t := map.tile_at(c)
		if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_VOID or t == GeneratedMap.TK_WINDOW:
			return dist * float(i) / float(steps)
	return -1.0


static func lerp_angle_safe(from: float, to: float, weight: float) -> float:
	return from + wrapf(to - from, -PI, PI) * clampf(weight, 0.0, 1.0)


static func angle_to(from: Vector2, to: Vector2) -> float:
	return (to - from).angle()


static func rotate_towards(current: float, target: float, max_rad: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	if absf(diff) <= max_rad:
		return target
	return current + signf(diff) * max_rad


static func random_point_in_rect(rng: RandomNumberGenerator, r: Rect2) -> Vector2:
	return Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))


static func weighted_pick(rng: RandomNumberGenerator, table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var roll := rng.randf() * total
	var acc := 0.0
	for k in table:
		acc += float(table[k])
		if roll <= acc:
			return str(k)
	return str(table.keys()[0]) if not table.is_empty() else ""


static func fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


static func fmt_cash(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-$" if amount < 0 else "$") + out


static func team_color(team: int) -> Color:
	return Db.TEAM_COLORS.get(team, Color.WHITE)


static func team_name(team: int) -> String:
	return str(Db.TEAM_NAMES.get(team, "?"))


static func signature(pos: Vector2) -> int:
	return int(abs(pos.x * 7.13 + pos.y * 3.71))


## Very small deterministic hash used to give each tile a stable "personality".
static func cell_noise(c: Vector2i, salt: int = 0) -> float:
	var n := int(c.x * 374761393 + c.y * 668265263 + salt * 1442695040)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(abs(n % 10000)) / 10000.0


static func dir_from_angle(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))


static func cone_contains(origin: Vector2, facing: float, point: Vector2, half_angle: float) -> bool:
	var a := (point - origin).angle()
	return absf(wrapf(a - facing, -PI, PI)) <= half_angle


static func screen_shake_multiplier() -> float:
	return float(GameFlow.profile.get("settings", {}).get("shake", 0.6))


static func blood_multiplier() -> float:
	return float(GameFlow.profile.get("settings", {}).get("blood", 1.0))
