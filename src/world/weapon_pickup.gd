class_name WeaponPickup
extends Node2D
## Ground weapon (arcade arms race uses these as upgrade stations), plus ammo.
## Anyone can grab it; the pickup keeps its remaining ammo.

var weapon_id := "pm9"
var mag := 0
var reserve := 0
var world: Node
var t := 0.0
var pickup_radius := 46.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if world != null and world.has_method("actors_all"):
		for a in world.call("actors_all"):
			if a.dead or a.is_civilian or a.visual == null:
				continue
			if a.global_position.distance_to(global_position) < pickup_radius:
				if a.loadout.has(weapon_id):
					# scavenger gets 50% more reserve ammo out of every corpse
					if world.has_method("ammo_from_corpse"):
						reserve = int(world.call("ammo_from_corpse", a, reserve))
					a.reserve = maxi(a.reserve, 0) + reserve
					reserve = 0
					queue_free()
					return
				a.add_weapon(weapon_id)
				a.switch_to(weapon_id)
				# scavenger picks guns up with a full magazine
				if Perks.pickup_comes_loaded(a):
					a.mag = int(Db.WEAPONS.get(weapon_id, {}).get("mag", mag))
				else:
					a.mag = mag
				a.reserve = reserve
				Sfx.play_at("pickup", global_position, -6.0)
				var short_name := str(Db.WEAPONS.get(weapon_id, {}).get("short", weapon_id))
				Signals.notify.emit("Подобрано: %s" % short_name, "info")
				queue_free()
				return


func _draw() -> void:
	var w: Dictionary = Db.WEAPONS.get(weapon_id, {})
	var col := Color(0.85, 0.9, 1.0, 0.8)
	var bob := sin(t * 2.0) * 2.0
	draw_set_transform(Vector2(0, bob), -0.35, Vector2.ONE)
	draw_rect(Rect2(-20, -3, 40, 6), Color(0.12, 0.14, 0.18), true)
	draw_rect(Rect2(-20, -3, 40, 6), col, false, 1.2)
	draw_rect(Rect2(-6, 3, 8, 9), Color(0.1, 0.1, 0.12), true)
	var kind := str(w.get("kind", ""))
	if kind == "melee":
		draw_line(Vector2(-20, 0), Vector2(26, 0), Color(0.85, 0.88, 0.92), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	var label := str(w.get("short", weapon_id))
	draw_string(font, Vector2(-26, -14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.7, 0.85, 1.0, 0.85))
