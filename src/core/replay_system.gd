class_name ReplaySystem
extends RefCounted
## Replay / highlight engine.
##
## The world records a cheap 12 Hz ring buffer of every actor (id, x, y, facing,
## weapon, dead flag). This class turns that buffer into the two things the game
## actually shows:
##
##   * a *multikill clip* -- the last N seconds before/after a kill streak was
##     scored, scored so the end-of-match screen can pick a winner;
##   * the *end-of-match highlight reel* -- the best clip plus the runner-ups.
##
## Separate from MatchWorld so the buffer math is testable and the HUD viewer can
## ask for "the clip for THIS kill" without reaching into world internals.

const CLIP_HZ := 12.0
const MAX_FRAMES := 90


## Compress a raw buffer into a clip dict the ReplayViewer understands.
static func make_clip(buffer: Array, killer: Actor, victim: Actor, streak: int, headshot: bool, label: String) -> Dictionary:
	var frames: Array = buffer.duplicate(true)
	return {
		"frames": frames,
		"label": label,
		"killer": killer.a_name if killer != null else "",
		"killer_id": killer.a_id if killer != null else 0,
		"killer_team": killer.team if killer != null else 2,
		"killer_outfit": killer.skin_outfit if killer != null else "heist",
		"victim": victim.a_name,
		"victim_id": victim.a_id,
		"victim_team": victim.team,
		"victim_outfit": victim.skin_outfit,
		"weapon": killer.current_weapon if killer != null else "",
		"headshot": headshot,
		"kills": streak,
		"score": clip_score(streak, headshot, killer),
		"streak": killer.kill_streak if killer != null else 0,
	}


## How "good" a clip was: multikills dominate, headshots/streaks add flavour and
## the local player gets a bonus so the end screen almost always shows *your* play.
static func clip_score(streak: int, headshot: bool, killer: Actor) -> int:
	var s := streak * 100
	if headshot:
		s += 60
	if killer != null and killer.kill_streak >= 5:
		s += 40
	if killer != null and killer.current_weapon in ["knife", "machete", "katana", "bat"]:
		s += 90
	return s


## Label for a streak count, Russian, in the game's tone.
static func streak_label(streak: int, headshot: bool) -> String:
	var label := "УБИЙСТВО"
	if streak == 2:
		label = "ДВОЙНОЕ УБИЙСТВО"
	elif streak == 3:
		label = "ТРОЙНОЕ УБИЙСТВО"
	elif streak >= 4:
		label = "МЯСОРУБКА x%d" % streak
	if headshot:
		label += " + В ГОЛОВУ"
	return label


## Pick the best clip for the end screen, with a title line for the HUD.
static func best_of(clips: Array) -> Dictionary:
	var best: Dictionary = {}
	for c in clips:
		if best.is_empty() or int(c.get("score", 0)) > int(best.get("score", 0)):
			best = c
	return best


## Total airtime of a clip, seconds -- the viewer uses it to size its timeline.
static func clip_duration(clip: Dictionary) -> float:
	var frames: Array = clip.get("frames", [])
	if frames.size() < 2:
		return 0.0
	return float(frames[frames.size() - 1].get("t", 0.0)) - float(frames[0].get("t", 0.0))


## Trim a buffer to the interesting window: [kill_time - 3.5s, kill_time + 1.0s].
static func window_around(buffer: Array, kill_time: float) -> Array:
	var out: Array = []
	for f in buffer:
		var t := float(f.get("t", 0.0))
		if t >= kill_time - 3.5 and t <= kill_time + 1.0:
			out.append(f)
	return out
