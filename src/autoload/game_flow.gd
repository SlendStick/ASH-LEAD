extends Node
## ASH&LEAD -- session state between menu and match.
##
## Holds the player's persistent identity (level, cash, unlocks, loadout),
## the active lobby configuration and the transitions between screens. Kept
## autoloaded so the match never needs to re-read files.

const SAVE_PATH := "user://ash_lead_profile.cfg"

signal screen_changed(screen: String)
signal prefs_changed(section: String)

var screen := "menu"
var profile: Dictionary = {}
var lobby_config: Dictionary = {}
var match_config: Dictionary = {}
var solo_with_bots := true
var bot_difficulty := 1  # 0 easy, 1 normal, 2 hard, 3 nightmare
var last_summary: Dictionary = {}
var player_codename := "БЕЗЫМЯННЫЙ"
var tips: Array[String] = []

const DEFAULT_LOADOUT := {
	"crim": {"primary": "vk9", "secondary": "pm9", "melee": "knife", "armor": "kevlar", "gadget_a": "smoke", "gadget_b": "flashbang", "perk": "ghost"},
	"police": {"primary": "m4", "secondary": "pm9", "melee": "baton", "armor": "kevlar", "gadget_a": "flashbang", "gadget_b": "medkit", "perk": "comms"},
}


func _ready() -> void:
	load_profile()
	lobby_config = {
		"mode": "heist", "map": "random", "team": 0, "bots_fill": true,
		"bot_count": 4, "difficulty": bot_difficulty, "friendly_fire": false,
		"rounds": 1, "replay": true, "max_minutes": 0,
	}


func load_profile() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	profile = {
		"name": "БЕЗЫМЯННЫЙ",
		"level": 1,
		"xp": 0,
		"cash": 12000,
		"stats": {"kills": 0, "deaths": 0, "headshots": 0, "heists": 0, "arrests": 0, "matches": 0, "hostages_saved": 0},
		"unlocks": ["vk9", "pm9", "knife", "m4", "baton"],
		"loadout_crim": DEFAULT_LOADOUT["crim"].duplicate(),
		"loadout_police": DEFAULT_LOADOUT["police"].duplicate(),
		"settings": {"master": 0.8, "music": 0.7, "sfx": 0.9, "blood": 1.0, "shake": 0.6, "fov_pulse": true, "language": "ru"},
		"video": {"crt": true, "crt_intensity": 0.55, "fog": true, "bloom": true, "scanlines": 480.0, "grain": 0.045, "aberration": 0.8},
		"outfit_crim": "heist",
		"outfit_police": "swat",
		"seen_intro": false,
	}
	if err == OK:
		for key in profile.keys():
			if cfg.has_section_key("profile", key):
				profile[key] = cfg.get_value("profile", key)
	player_codename = str(profile.get("name", "БЕЗЫМЯННЫЙ"))
	bot_difficulty = int(profile.get("difficulty", 1))
	apply_audio_settings()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	for key in profile.keys():
		cfg.set_value("profile", key, profile[key])
	cfg.save(SAVE_PATH)


func apply_audio_settings() -> void:
	var s: Dictionary = profile.get("settings", {})
	var master := int(float(s.get("master", 0.8)) * 100.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.001, float(s.get("master", 0.8)))))
	var mi := AudioServer.get_bus_index("Music")
	if mi != -1:
		AudioServer.set_bus_volume_db(mi, linear_to_db(max(0.001, float(s.get("music", 0.7)))) - 6.0)
	var si := AudioServer.get_bus_index("SFX")
	if si != -1:
		AudioServer.set_bus_volume_db(si, linear_to_db(max(0.001, float(s.get("sfx", 0.9)))) - 2.0)
	if master < 0:
		master = 0


## Full wipe back to a fresh profile (settings screen "reset progress").
func reset_progress() -> void:
	var old_name := str(profile.get("name", "БЕЗЫМЯННЫЙ"))
	var old_settings: Dictionary = profile.get("settings", {}).duplicate(true)
	var old_video: Dictionary = profile.get("video", {}).duplicate(true)
	profile = {
		"name": old_name, "level": 1, "xp": 0, "cash": 12000,
		"stats": {"kills": 0, "deaths": 0, "headshots": 0, "heists": 0, "arrests": 0, "matches": 0, "hostages_saved": 0},
		"unlocks": ["vk9", "pm9", "knife", "m4", "baton"],
		"loadout_crim": DEFAULT_LOADOUT["crim"].duplicate(),
		"loadout_police": DEFAULT_LOADOUT["police"].duplicate(),
		"settings": old_settings,
		"video": old_video,
		"outfit_crim": "heist", "outfit_police": "swat", "seen_intro": true,
	}
	player_codename = old_name
	save_profile()
	prefs_changed.emit("all")


func set_screen(s: String) -> void:
	screen = s
	screen_changed.emit(s)


func start_solo(bots: bool = true) -> void:
	solo_with_bots = bots
	match_config = lobby_config.duplicate(true)
	match_config["bots_fill"] = bots
	if bots:
		match_config["bot_count"] = int(lobby_config.get("bot_count", 4))
	set_screen("loading")
	get_tree().change_scene_to_file("res://scenes/loading.tscn")


func start_host() -> void:
	solo_with_bots = false
	match_config = lobby_config.duplicate(true)
	set_screen("loading")
	get_tree().change_scene_to_file("res://scenes/loading.tscn")


func back_to_menu() -> void:
	set_screen("menu")
	Sfx.play_music("menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func add_xp(amount: int) -> void:
	var xp := int(profile.get("xp", 0)) + amount
	profile["xp"] = xp
	var lvl := int(profile.get("level", 1))
	while xp >= level_xp(lvl):
		xp -= level_xp(lvl)
		lvl += 1
		profile["level"] = lvl
		notify("НОВЫЙ УРОВЕНЬ: %d" % lvl)
	profile["xp"] = xp


func level_xp(level: int) -> int:
	return 500 + level * 250


func add_cash(amount: int) -> void:
	profile["cash"] = int(profile.get("cash", 0)) + amount


func record_stat(key: String, amount: int = 1) -> void:
	var stats: Dictionary = profile.get("stats", {})
	stats[key] = int(stats.get(key, 0)) + amount
	profile["stats"] = stats


func is_unlocked(item: String) -> bool:
	var unlocks: Array = profile.get("unlocks", [])
	return unlocks.has(item) or float(Db.WEAPONS.get(item, {"price": 0}).get("price", 0)) <= 0


func notify(text: String) -> void:
	Signals.notify.emit(text, "info")


func random_tip() -> String:
	if tips.is_empty():
		tips = [
			"Стреляй в голову — экономишь патроны и время.",
			"Дверь можно выбить ногой, но весь этаж узнает, что ты здесь.",
			"Гражданские — не мишени. Но и не союзники.",
			"Тихий нож за спиной не поднимает тревогу.",
			"Полиция приезжает по таймеру или по тревоге. Что раньше.",
			"Труп, найденный охранником, — это тоже тревога.",
			"После смерти можно вселиться в бота своей команды.",
			"Ботам можно приказать держать, идти следом, штурмовать или отступить.",
			"Сумка с деньгами замедляет. Оставь её — и потеряешь всё.",
			"Свет — это информация. Гасите свет, если хотите спрятаться.",
		]
	return tips[randi_range(0, tips.size() - 1)]
