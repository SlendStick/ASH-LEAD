class_name PlantMode
extends GameMode
## «Установка»: criminals activate a fictional device in one of two zones,
## police prevent it or disable it. Halves swap sides. No respawns.

var devices: Array = []
var device_timer: float = 25.0
var plant_duration: float = 4.0
var defuse_duration: float = 5.0
var _round_over: bool = false


func _on_setup() -> void:
	match_ref.config["respawn"] = false
	match_ref.config["downed_enabled"] = false
	var count := mini(2, maxi(1, match_ref.map_data.objectives.size()))
	for i in count:
		var obj: Dictionary = match_ref.map_data.objectives[i]
		var device := Interactable.InteractDevice.new(match_ref, obj["pos"], "plant", "device_name", plant_duration)
		device.zone_index = i
		match_ref.register_interactable(device)
		devices.append(device)
	match_ref.feed(Localization.t("objective_plant"))


func _on_update(delta: float) -> void:
	if match_ref.phase != GameTypes.GamePhase.ACTIVE:
		return
	if _round_over:
		return
	if device_planted:
		device_timer -= delta
		if device_timer <= 0.0:
			end_round(GameTypes.Team.CRIMINALS, "reason_device_activated")
			return
	elif match_ref.phase_time >= round_time:
		end_round(GameTypes.Team.POLICE, "reason_time_up")
		return
	check_elimination()


func on_device_planted(device, character: Character) -> void:
	if device_planted:
		return
	device_planted = true
	device_timer = 25.0
	device.action = "defuse"
	device.prompt_key = "defuse_device"
	device.duration = defuse_duration
	for other in devices:
		if other != device:
			other.enabled = false
	match_ref.record_stat(character, "objectives")
	match_ref.resonance.add_alarm(device.global_position)
	match_ref.play_sound("plant_beep", device.global_position)
	match_ref.feed(Localization.t("feed_device_planted"))
	add_highlight("objective", {"pos": device.global_position, "type": "plant"})


func on_device_defused(device, character: Character) -> void:
	if not device_planted:
		return
	match_ref.record_stat(character, "objectives")
	match_ref.play_sound("defuse_beep", device.global_position)
	end_round(GameTypes.Team.POLICE, "reason_device_defused")


func get_objective_text() -> String:
	if device_planted:
		return Localization.t("objective_defuse")
	return Localization.t("objective_plant")


func get_phase_text() -> String:
	if match_ref.phase == GameTypes.GamePhase.PREP:
		return Localization.t("phase_prep")
	if device_planted:
		return Localization.t("phase_device_active")
	return Localization.t("phase_active")
