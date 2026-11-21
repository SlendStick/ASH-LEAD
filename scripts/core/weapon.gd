class_name Weapon
extends RefCounted
## A weapon instance: stats from data/weapons.json plus live ammo state.

var data: Dictionary = {}
var id: String = ""
var ammo_in_mag: int = 0
var reserve: int = 0
var reloading: bool = false
var reload_time_left: float = 0.0
var cooldown: float = 0.0
var reload_total: float = 1.0


func _init(weapon_data: Dictionary, reserve_scale: float = 1.0) -> void:
	data = weapon_data
	id = String(data.get("id", ""))
	ammo_in_mag = int(data.get("mag", 0))
	var res := int(data.get("reserve", 0))
	reserve = int(res * reserve_scale)
	reload_total = float(data.get("reload", 1.0))


func weapon_class() -> String:
	return String(data.get("class", "pistol"))


var name: String:
	get:
		return String(data.get("name", id))


var is_auto: bool:
	get:
		return bool(data.get("auto", false))


var rpm: float:
	get:
		return float(data.get("rpm", 60))


var interval: float:
	get:
		return 60.0 / max(1.0, rpm)


var damage: float:
	get:
		return float(data.get("damage", 10))


var pellets: int:
	get:
		return int(data.get("pellets", 1))


var range: float:
	get:
		return float(data.get("range", 400))


var noise: float:
	get:
		return float(data.get("noise", 0.5))


var is_melee: bool:
	get:
		return id == "knife" or String(data.get("class", "")) == "melee"


func can_fire() -> bool:
	return not reloading and cooldown <= 0.0 and ammo_in_mag > 0


func consume() -> void:
	ammo_in_mag = maxi(0, ammo_in_mag - 1)
	cooldown = interval


func update(delta: float) -> void:
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
	if reloading:
		reload_time_left -= delta
		if reload_time_left <= 0.0:
			reloading = false
			var need := int(data.get("mag", 0)) - ammo_in_mag
			var take := mini(need, reserve)
			ammo_in_mag += take
			reserve -= take


func start_reload(speed_scale: float = 1.0) -> bool:
	if reloading or ammo_in_mag >= int(data.get("mag", 0)) or reserve <= 0:
		return false
	reloading = true
	reload_time_left = reload_total * clampf(speed_scale, 0.4, 2.0)
	return true


func cancel_reload() -> void:
	reloading = false
	reload_time_left = 0.0


## Effective spread in degrees, modified by stance, movement and suppression.
func effective_spread(character: Character) -> float:
	var spread := float(data.get("spread", 2.0))
	if character.crouching:
		spread *= 0.65
	if character.aiming:
		spread *= 0.7
	if character.move_dir.length() > 0.1:
		spread *= 1.7
	if character.suppression > 0.0:
		spread *= 1.0 + character.suppression * 0.9
	if character.sprinting:
		spread *= 2.2
	return spread


func display_stats() -> Dictionary:
	return {
		"damage": damage,
		"rpm": rpm,
		"mag": int(data.get("mag", 0)),
		"reserve": reserve,
		"range": range,
	}
