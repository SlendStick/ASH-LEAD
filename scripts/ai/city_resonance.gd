class_name CityResonance
extends Node
## «Резонанс города»: a shared tension meter linking sound, alarm and the
## reaction of the world. It never reveals exact enemy positions; it changes
## NPC behaviour, escalation speed and how ready the response forces are.

const DECAY := 1.6
const PANIC_RADIUS := 620.0

var value: float = 0.0
var alarm_active: bool = false
var alarm_timer: float = 0.0
var panic_events: Array = []


func reset() -> void:
	value = 0.0
	alarm_active = false
	alarm_timer = 0.0
	panic_events.clear()


func add_noise_event(pos: Vector2, loudness: float) -> void:
	value = clampf(value + 9.0 * loudness, 0.0, 100.0)


func add_gunfire(pos: Vector2, loudness: float) -> void:
	value = clampf(value + 16.0 * loudness, 0.0, 100.0)


func add_alarm(pos: Vector2) -> void:
	alarm_active = true
	alarm_timer = 25.0
	value = clampf(value + 22.0, 0.0, 100.0)


func add_panic(pos: Vector2) -> void:
	panic_events.append({"pos": pos, "time": 4.0})
	value = clampf(value + 7.0, 0.0, 100.0)


func add_civilian_hurt() -> void:
	value = clampf(value + 18.0, 0.0, 100.0)


func add_civilian_saved() -> void:
	value = clampf(value - 8.0, 0.0, 100.0)


func add_civilian_evacuated() -> void:
	value = clampf(value - 5.0, 0.0, 100.0)


func update(delta: float, match_ref) -> void:
	value = clampf(value - DECAY * delta * (0.4 if alarm_active else 1.0), 0.0, 100.0)
	if alarm_active:
		alarm_timer -= delta
		if alarm_timer <= 0.0:
			alarm_active = false
	var i := panic_events.size() - 1
	while i >= 0:
		var e: Dictionary = panic_events[i]
		e["time"] = float(e["time"]) - delta
		if float(e["time"]) <= 0.0:
			panic_events.remove_at(i)
		i -= 1
	# Nearby panicking civilians spread unrest.
	if match_ref != null:
		for e in panic_events:
			for civ in match_ref.characters:
				if civ.team != GameTypes.Team.CIVILIAN or not civ.alive:
					continue
				if civ.global_position.distance_to(e["pos"]) < PANIC_RADIUS:
					civ.controller.on_panic_nearby(e["pos"])


func level() -> int:
	if value >= 75.0:
		return GameTypes.AlertState.CRISIS
	if value >= 50.0:
		return GameTypes.AlertState.ALARM
	if value >= 28.0:
		return GameTypes.AlertState.SEARCH
	if value >= 10.0:
		return GameTypes.AlertState.SUSPICIOUS
	return GameTypes.AlertState.CALM


func level_name() -> String:
	match level():
		GameTypes.AlertState.CRISIS:
			return Localization.t("alert_crisis")
		GameTypes.AlertState.ALARM:
			return Localization.t("alert_alarm")
		GameTypes.AlertState.SEARCH:
			return Localization.t("alert_search")
		GameTypes.AlertState.SUSPICIOUS:
			return Localization.t("alert_suspicious")
	return Localization.t("alert_calm")


func police_readiness() -> float:
	# 0..1: how prepared the response is. High resonance means faster arrival.
	return clampf(0.35 + value / 140.0, 0.0, 1.0)
