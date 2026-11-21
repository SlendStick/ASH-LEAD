extends Node
## Persistent user settings: audio, accessibility, controls helpers.
## Stored in user://settings.json.

signal settings_changed(key: String)

const SETTINGS_PATH := "user://settings.json"

const DEFAULTS := {
	"mouse_sensitivity": 1.0,
	"volume_master": 0.9,
	"volume_music": 0.7,
	"volume_sfx": 1.0,
	"volume_ambient": 0.7,
	"volume_voice": 1.0,
	"blood_level": 2,
	"flash_effects": true,
	"screen_shake": true,
	"camera_zoom": 1.0,
	"camera_lag": 0.12,
	"camera_follow": true,
	"ui_scale": 1.0,
	"subtitles": true,
	"subtitle_size": 18,
	"colorblind_mode": 0,
	"high_contrast": false,
	"language": 0,
	"show_fps": false,
	"noise_indicators": true,
	"music_enabled": true,
	"sfx_enabled": true,
	"chat_text": true,
	"voice_chat": false,
}

var settings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_ui_scale()
	_apply_language_deferred()


func _apply_language_deferred() -> void:
	# Localization is a later autoload: apply the stored language on the next
	# idle frame so the node is guaranteed to exist.
	var loc := get_node_or_null("/root/Localization")
	if loc != null:
		loc.language = _language_code()
	else:
		call_deferred("_apply_language_deferred")


func _language_code() -> String:
	return "ru" if int(get_setting("language")) == 0 else "en"


func apply_ui_scale() -> void:
	var scale := float(get_setting("ui_scale"))
	if scale <= 0.0:
		return
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = scale


func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULTS.get(key))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit(key)
	match key:
		"volume_master", "volume_music", "volume_sfx", "volume_ambient", "volume_voice":
			apply_audio()
		"music_enabled":
			apply_audio()
			if not value:
				AudioManager.stop_music()
		"language":
			Localization.language = "ru" if int(value) == 0 else "en"
		"ui_scale":
			apply_ui_scale()
	save_settings()


func reset_to_defaults() -> void:
	settings = DEFAULTS.duplicate(true)
	apply_audio()
	save_settings()
	settings_changed.emit("all")


func apply_audio() -> void:
	_set_bus_volume("Master", get_setting("volume_master"))
	_set_bus_volume("Music", get_setting("volume_music"))
	_set_bus_volume("SFX", get_setting("volume_sfx"))
	_set_bus_volume("Ambient", get_setting("volume_ambient"))
	_set_bus_volume("Voice", get_setting("volume_voice"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not get_setting("music_enabled"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not get_setting("sfx_enabled"))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var db := linear_to_db(clampf(linear, 0.0001, 1.0))
	AudioServer.set_bus_volume_db(idx, db)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("ASH&LEAD: cannot write settings (%s)" % SETTINGS_PATH)
		return
	f.store_string(JSON.stringify(settings, "  "))
	f.close()


func load_settings() -> void:
	settings = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		for key in parsed:
			if DEFAULTS.has(key):
				settings[key] = parsed[key]
