class_name U
extends RefCounted
## Small helpers shared by gameplay, AI and UI code.


static func clampf(v: float, lo: float, hi: float) -> float:
	return max(lo, min(hi, v))


static func clampi(v: int, lo: int, hi: int) -> int:
	return max(lo, min(hi, v))


static func angle_diff(a: float, b: float) -> float:
	var d := fmod(b - a, TAU)
	if d > PI:
		d -= TAU
	elif d < -PI:
		d += TAU
	return d


static func lerp_angle(a: float, b: float, t: float) -> float:
	return a + angle_diff(a, b) * clampf(t, 0.0, 1.0)


static func randf_range(rng: RandomNumberGenerator, lo: float, hi: float) -> float:
	return lo + rng.randf() * (hi - lo)


static func chance(rng: RandomNumberGenerator, probability: float) -> bool:
	return rng.randf() < probability


static func pick(rng: RandomNumberGenerator, arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi() % arr.size()]


## Returns an index into `weights` chosen proportionally.
static func weighted_pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += max(0.0, float(w))
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += max(0.0, float(weights[i]))
		if roll <= acc:
			return i
	return weights.size() - 1


static func format_time(seconds: float) -> String:
	var s := int(max(0.0, seconds))
	return "%02d:%02d" % [s / 60, s % 60]


static func format_int(value: int) -> String:
	var neg := value < 0
	var digits := str(abs(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if neg else "") + out


static func bresenham(a: Vector2i, b: Vector2i) -> Array:
	var points: Array = []
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err: int = dx - dy
	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return points


static func seed_from_string(text: String) -> int:
	var h := 2166136261
	for i in text.length():
		h = (h ^ int(text.unicode_at(i))) * 16777619
		h = h & 0x7FFFFFFF
	return int(h)


static func dir_to_angle(dir: Vector2) -> float:
	return dir.angle()


static func is_valid_team(team: int) -> bool:
	return team == GameTypes.Team.CRIMINALS or team == GameTypes.Team.POLICE
