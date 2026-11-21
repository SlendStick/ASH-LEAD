class_name ReplayRecorder
extends Node
## Records real match snapshots and events. Highlights are chosen from actual
## recorded events; playback interpolates the recorded frames.

const HZ := 10.0
const MAX_FRAMES := 1200
const SNAPSHOT_FIELDS := ["name", "team", "pos", "aim", "alive", "hp"]

var match_ref: Match
var frames: Array = []
var events: Array = []
var recording: bool = false
var _timer := 0.0


func start(match_ref: Match) -> void:
	match_ref = match_ref
	frames.clear()
	events.clear()
	recording = true
	_timer = 0.0


func stop() -> void:
	recording = false


func update(delta: float) -> void:
	if not recording or match_ref == null:
		return
	_timer += delta
	if _timer < 1.0 / HZ:
		return
	_timer = 0.0
	var snapshot := {"t": match_ref.elapsed, "chars": []}
	for c in match_ref.characters:
		if c.team == GameTypes.Team.CIVILIAN:
			continue
		snapshot["chars"].append({
			"name": c.char_name,
			"team": c.team,
			"pos": c.global_position,
			"aim": c.aim_dir.angle(),
			"alive": c.alive,
			"hp": c.hp,
		})
	frames.append(snapshot)
	if frames.size() > MAX_FRAMES:
		frames.pop_front()


func record_event(type: String, data: Dictionary) -> void:
	if not recording:
		return
	events.append({"t": match_ref.elapsed, "type": type, "data": data})


## Short, skippable highlights picked from real events.
func get_highlights() -> Array:
	var kills: Array = []
	for e in events:
		if String(e["type"]) == "kill":
			kills.append(e)
	var highlights: Array = []
	if not kills.is_empty():
		highlights.append({"type": "kill", "t": float(kills[-1]["t"]), "title_key": "highlight_last_kill", "data": kills[-1]["data"]})
	# Most notable multi-kill from mode tracking.
	if match_ref != null and match_ref.mode != null:
		for h in match_ref.mode.get_highlights():
			if String(h["type"]) == "multikill":
				var t := float(kills[-1]["t"]) if not kills.is_empty() else 0.0
				highlights.append({"type": "multikill", "t": t, "title_key": "highlight_multikill", "data": h["data"]})
				break
		for h in match_ref.mode.get_highlights():
			if String(h["type"]) == "objective":
				highlights.append({"type": "objective", "t": 0.0, "title_key": "highlight_objective", "data": h["data"]})
				break
	# Deciding moment: last event before the end.
	if not events.is_empty():
		var last_event: Dictionary = events[events.size() - 1]
		highlights.append({"type": "decisive", "t": float(last_event["t"]), "title_key": "highlight_decisive", "data": last_event["data"]})
	# Deduplicate by type, keep the first four.
	var seen := {}
	var out: Array = []
	for h in highlights:
		var key: String = h["type"]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(h)
	return out.slice(0, 4)


func get_frames_between(from_time: float, to_time: float) -> Array:
	var out: Array = []
	for f in frames:
		var t := float(f["t"])
		if t >= from_time and t <= to_time:
			out.append(f)
	if out.is_empty() and not frames.is_empty():
		out.append(frames[0])
	return out
