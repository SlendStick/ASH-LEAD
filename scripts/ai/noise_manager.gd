class_name NoiseManager
extends Node
## Sound events with limited lifetime. AI receives direction and approximate
## area, never exact coordinates of the source.

const EVENT_LIFETIME := 3.0

var events: Array = []


func add_noise(pos: Vector2, loudness: float, radius: float, source) -> void:
	events.append({
		"pos": pos,
		"loudness": clampf(loudness, 0.05, 1.0),
		"radius": radius,
		"time": EVENT_LIFETIME,
		"source": source,
	})
	if events.size() > 64:
		events.pop_front()


func update(delta: float) -> void:
	var i := events.size() - 1
	while i >= 0:
		var e: Dictionary = events[i]
		e["time"] = float(e["time"]) - delta
		if float(e["time"]) <= 0.0:
			events.remove_at(i)
		i -= 1


## Events the observer could plausibly hear, with confidence instead of exact
## coordinates.
func query(observer_pos: Vector2, hearing_scale: float = 1.0) -> Array:
	var out: Array = []
	for e in events:
		var dist: float = observer_pos.distance_to(e["pos"])
		var radius: float = e["radius"] * hearing_scale
		if dist > radius:
			continue
		var confidence := clampf(1.0 - dist / maxf(1.0, radius), 0.0, 1.0)
		out.append({
			"pos": e["pos"],
			"direction": (e["pos"] - observer_pos).normalized(),
			"loudness": e["loudness"],
			"confidence": confidence * e["loudness"],
			"source": e["source"],
		})
	return out


func clear() -> void:
	events.clear()
