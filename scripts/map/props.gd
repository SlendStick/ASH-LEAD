class_name Props
extends RefCounted
## Definitions of placeable map props (top-down).

## name -> {texture, w, h, tall, bullet_block, cover, rotate}
const DEFS := {
	"crate": {"texture": "prop_crate", "w": 64, "h": 64, "tall": false, "bullet_block": false, "cover": true},
	"shelf": {"texture": "prop_shelf", "w": 48, "h": 96, "tall": true, "bullet_block": true, "cover": true},
	"shelf_long": {"texture": "prop_shelf_long", "w": 128, "h": 48, "tall": true, "bullet_block": true, "cover": true},
	"table": {"texture": "prop_table", "w": 72, "h": 56, "tall": false, "bullet_block": false, "cover": true},
	"desk": {"texture": "prop_desk", "w": 96, "h": 56, "tall": false, "bullet_block": false, "cover": true},
	"bed": {"texture": "prop_bed", "w": 96, "h": 64, "tall": false, "bullet_block": false, "cover": true},
	"locker": {"texture": "prop_locker", "w": 40, "h": 80, "tall": true, "bullet_block": true, "cover": true},
	"server": {"texture": "prop_server", "w": 48, "h": 64, "tall": true, "bullet_block": true, "cover": true},
	"sofa": {"texture": "prop_sofa", "w": 96, "h": 48, "tall": false, "bullet_block": false, "cover": true},
	"vending": {"texture": "prop_vending", "w": 48, "h": 64, "tall": false, "bullet_block": false, "cover": true},
	"plant": {"texture": "prop_plant", "w": 48, "h": 48, "tall": false, "bullet_block": false, "cover": true},
	"sandbags": {"texture": "prop_sandbags", "w": 96, "h": 32, "tall": false, "bullet_block": false, "cover": true},
	"car_blue": {"texture": "prop_car_blue", "w": 160, "h": 80, "tall": true, "bullet_block": true, "cover": true},
	"car_red": {"texture": "prop_car_red", "w": 160, "h": 80, "tall": true, "bullet_block": true, "cover": true},
	"counter": {"texture": "prop_counter", "w": 128, "h": 48, "tall": false, "bullet_block": false, "cover": true},
	"reception": {"texture": "prop_reception", "w": 144, "h": 64, "tall": false, "bullet_block": false, "cover": true},
	"archive_shelf": {"texture": "prop_archive_shelf", "w": 112, "h": 44, "tall": true, "bullet_block": true, "cover": true},
	"bookshelf": {"texture": "prop_bookshelf", "w": 120, "h": 44, "tall": true, "bullet_block": true, "cover": true},
	"filing": {"texture": "prop_filing", "w": 40, "h": 56, "tall": true, "bullet_block": true, "cover": true},
	"stage": {"texture": "prop_stage", "w": 160, "h": 96, "tall": false, "bullet_block": false, "cover": true},
	"cinema_rows": {"texture": "prop_cinema_rows", "w": 128, "h": 96, "tall": false, "bullet_block": false, "cover": true},
	"gym_mat": {"texture": "prop_gym_mat", "w": 128, "h": 64, "tall": false, "bullet_block": false, "cover": false},
	"popcorn": {"texture": "prop_popcorn", "w": 56, "h": 56, "tall": false, "bullet_block": false, "cover": true},
	"dumpster": {"texture": "prop_dumpster", "w": 96, "h": 64, "tall": true, "bullet_block": true, "cover": true},
	"barrel": {"texture": "prop_barrel", "w": 32, "h": 32, "tall": false, "bullet_block": false, "cover": true},
	"kiosk": {"texture": "prop_kiosk", "w": 64, "h": 64, "tall": true, "bullet_block": true, "cover": true},
	"atm": {"texture": "prop_atm", "w": 48, "h": 64, "tall": true, "bullet_block": true, "cover": true},
	"bench": {"texture": "prop_bench", "w": 96, "h": 32, "tall": false, "bullet_block": false, "cover": true},
}


static func get_def(name: String) -> Dictionary:
	return DEFS.get(name, DEFS["crate"])


static func texture_path(name: String) -> String:
	return "res://assets/textures/%s.png" % String(get_def(name).get("texture", "prop_crate"))


static func random_for_theme(theme: String, rng: RandomNumberGenerator) -> String:
	var table := {
		"clinic": ["reception", "bed", "locker", "desk", "plant", "bench", "vending", "server", "filing"],
		"warehouse": ["crate", "shelf", "shelf_long", "desk", "barrel", "dumpster", "car_blue", "bench", "filing"],
		"college": ["desk", "bench", "locker", "gym_mat", "server", "bookshelf", "filing", "plant", "table"],
		"cinema": ["cinema_rows", "stage", "popcorn", "sofa", "kiosk", "vending", "counter", "bench"],
		"mall": ["kiosk", "sofa", "plant", "vending", "atm", "counter", "bench", "car_blue", "table"],
		"archive": ["archive_shelf", "filing", "desk", "server", "locker", "plant", "counter", "bookshelf"],
	}
	var list: Array = table.get(theme, ["crate"])
	return String(list[rng.randi() % list.size()])
