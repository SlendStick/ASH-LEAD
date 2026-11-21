class_name Perception
extends RefCounted
## Shared visibility/hearing model for bots, civilians and guards.
## Darkness helps but never makes a character invisible: a close observer
## still notices someone standing in shadow.

const VISION_RANGE := 940.0
const VISION_FOV := 2.1
const HEARING_BASE := 520.0


static func visibility(observer: Character, target: Character, map_view: MapView) -> float:
	if observer == null or target == null or not target.alive:
		return 0.0
	var dist := observer.global_position.distance_to(target.global_position)
	if dist > VISION_RANGE:
		return 0.0
	var dir := (target.global_position - observer.global_position).normalized()
	var ang := absf(U.angle_diff(observer.aim_dir.angle(), dir.angle()))
	# Peripheral vision only at very short range.
	if ang > VISION_FOV * 0.5 and dist > MapData.TILE_SIZE * 2.0:
		return 0.0
	if not map_view.map.has_los(observer.global_position, target.global_position):
		return 0.0
	var light := map_view.light_at(target.global_position)
	var light_factor := clampf(0.22 + light * 0.95, 0.0, 1.25)
	var dist_factor := 1.0 - dist / VISION_RANGE
	var posture := 0.5 if target.crouching else 1.0
	var movement := 0.65 + 0.35 * clampf(target.move_dir.length(), 0.0, 1.0)
	var visibility := light_factor * (0.3 + 0.7 * dist_factor) * posture * movement
	if target.stealth_mode:
		visibility *= 0.55
	return clampf(visibility, 0.0, 1.0)


static func can_see(observer: Character, target: Character, map_view: MapView) -> bool:
	return visibility(observer, target, map_view) > 0.28


static func hearing_radius(loudness: float) -> float:
	return HEARING_BASE * clampf(loudness, 0.05, 1.0) * 1.6


static func hearing_level(loudness: float, distance: float) -> float:
	var radius := hearing_radius(loudness)
	if distance > radius:
		return 0.0
	return clampf(1.0 - distance / radius, 0.0, 1.0)
