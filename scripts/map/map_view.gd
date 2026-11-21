class_name MapView
extends Node2D
## Renders a MapData: tiles, merged wall colliders, props, doors, lights,
## occluders and the darkness modulator. Also computes the light level grid
## used by stealth detection.

const TILE := 64.0

var map: MapData
var tile_layer: TileMapLayer
var walls_root: Node2D
var props_root: Node2D
var doors_root: Node2D
var lights_root: Node2D
var occluders_root: Node2D
var darkness: CanvasModulate
var light_texture: Texture2D
var _light_sources: Array = []
var _lightmap_timer := 0.0
var _time := 0.0


func _ready() -> void:
	light_texture = _make_radial_texture(128)


func setup(map_data: MapData) -> void:
	map = map_data
	_build_tiles()
	_build_walls()
	_build_props()
	_build_doors()
	_build_lights()
	_build_occluders()
	_build_darkness()
	update_lightmap()


func world_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(map.width, map.height) * TILE)


# ---- tiles -----------------------------------------------------------------

func _build_tiles() -> void:
	tile_layer = TileMapLayer.new()
	add_child(tile_layer)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(int(TILE), int(TILE))
	var names := ["floor_concrete", "floor_tile", "floor_wood", "floor_carpet",
		"wall", "wall_dark", "glass", "door", "road", "pavement", "grate", "puddle"]
	var sources := {}
	for n in names:
		var src := TileSetAtlasSource.new()
		src.texture = load("res://assets/textures/%s.png" % n)
		src.texture_region_size = Vector2i(int(TILE), int(TILE))
		src.create_tile(Vector2i(0, 0))
		var id := ts.add_source(src)
		sources[n] = id
	tile_layer.tile_set = ts
	for y in map.height:
		for x in map.width:
			var t := int(map.tiles[map.idx(x, y)])
			var tex_name := _tile_texture(t, int(map.variant[map.idx(x, y)]))
			var src_id: int = sources.get(tex_name, 0)
			tile_layer.set_cell(Vector2i(x, y), src_id, Vector2i(0, 0), 0)


func _tile_texture(t: int, variant: int) -> String:
	match t:
		MapData.Tile.FLOOR:
			var floors := [map.floor_texture, "floor_concrete", "floor_tile", "floor_wood", "floor_carpet"]
			if variant > 0 and variant < floors.size():
				return floors[variant]
			return map.floor_texture
		MapData.Tile.WALL:
			return map.wall_texture
		MapData.Tile.DOOR:
			return "door"
		MapData.Tile.GLASS:
			return "glass"
		MapData.Tile.ROAD:
			return "road"
		MapData.Tile.OUTSIDE:
			return "pavement"
		MapData.Tile.GRATE:
			return "grate"
		MapData.Tile.PUDDLE:
			return "puddle"
		_:
			return "floor_concrete"


# ---- walls -----------------------------------------------------------------

func _build_walls() -> void:
	walls_root = Node2D.new()
	walls_root.name = "Walls"
	add_child(walls_root)
	for y in map.height:
		var run_start := -1
		for x in map.width + 1:
			var is_wall := x < map.width and int(map.tiles[map.idx(x, y)]) == MapData.Tile.WALL
			if is_wall and run_start < 0:
				run_start = x
			elif not is_wall and run_start >= 0:
				_add_wall_rect(Rect2i(run_start, y, x - run_start, 1))
				run_start = -1
	# Vertical runs reduce body count for tall walls.
	for x in map.width:
		var run_start := -1
		for y in map.height + 1:
			var is_wall := y < map.height and int(map.tiles[map.idx(x, y)]) == MapData.Tile.WALL
			if is_wall and run_start < 0:
				run_start = y
			elif not is_wall and run_start >= 0:
				if y - run_start >= 4:
					_add_wall_rect(Rect2i(x, run_start, 1, y - run_start))
				run_start = -1


func _add_wall_rect(rect: Rect2i) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(rect.size.x * TILE, rect.size.y * TILE)
	shape.shape = rectangle
	body.add_child(shape)
	body.position = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5) * TILE
	walls_root.add_child(body)


# ---- props -----------------------------------------------------------------

func _build_props() -> void:
	props_root = Node2D.new()
	props_root.name = "Props"
	add_child(props_root)
	for prop in map.props:
		var def: Dictionary = Props.get_def(prop["type"])
		var node := Node2D.new()
		node.position = prop["pos"]
		node.rotation = float(prop.get("rot", 0.0))
		var sprite := Sprite2D.new()
		sprite.texture = load(Props.texture_path(prop["type"]))
		node.add_child(sprite)
		if bool(def.get("cover", true)):
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(float(def["w"]), float(def["h"]))
			shape.shape = rectangle
			body.add_child(shape)
			node.add_child(body)
		props_root.add_child(node)


# ---- doors -----------------------------------------------------------------

func _build_doors() -> void:
	doors_root = Node2D.new()
	doors_root.name = "Doors"
	add_child(doors_root)
	for info in map.doors:
		var door := Door.new()
		doors_root.add_child(door)
		door.setup(map, info["pos"], info)


func get_doors() -> Array:
	var out: Array = []
	if doors_root == null:
		return out
	for child in doors_root.get_children():
		if child is Door:
			out.append(child)
	return out


# ---- lights ----------------------------------------------------------------

func _build_lights() -> void:
	lights_root = Node2D.new()
	lights_root.name = "Lights"
	add_child(lights_root)
	for info in map.lights:
		var light := PointLight2D.new()
		light.texture = light_texture
		light.position = info["pos"]
		light.color = info["color"]
		light.energy = float(info.get("energy", 1.0))
		light.texture_scale = float(info.get("radius", 200.0)) / (light_texture.get_width() * 0.5)
		light.shadow_enabled = false
		light.blend_mode = PointLight2D.BLEND_MODE_ADD
		lights_root.add_child(light)
		_light_sources.append({"light": light, "base": light.energy, "flicker": bool(info.get("flicker", false)), "phase": randf() * TAU})


func _build_occluders() -> void:
	occluders_root = Node2D.new()
	occluders_root.name = "Occluders"
	add_child(occluders_root)
	for y in map.height:
		var run_start := -1
		for x in map.width + 1:
			var is_wall := x < map.width and int(map.tiles[map.idx(x, y)]) == MapData.Tile.WALL
			if is_wall and run_start < 0:
				run_start = x
			elif not is_wall and run_start >= 0:
				_add_occluder(Rect2i(run_start, y, x - run_start, 1))
				run_start = -1


func _add_occluder(rect: Rect2i) -> void:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var w := rect.size.x * TILE
	var h := rect.size.y * TILE
	poly.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5),
		Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5),
		Vector2(-w * 0.5, h * 0.5),
	])
	occ.occluder = poly
	occ.position = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5) * TILE
	occluders_root.add_child(occ)


func _build_darkness() -> void:
	darkness = CanvasModulate.new()
	var base := map.ambient
	darkness.color = Color(base * 0.55, base * 0.62, base * 0.8, 1.0)
	add_child(darkness)


func _make_radial_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - half + 0.5, y - half + 0.5).length() / half
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ---- light level grid ------------------------------------------------------

func update_lightmap() -> void:
	if map == null:
		return
	var lights := []
	for info in map.lights:
		lights.append(info)
	for y in map.height:
		for x in map.width:
			var i := map.idx(x, y)
			var level := map.ambient
			var world := map.tile_center_world(x, y)
			for info in lights:
				var d: float = (world - info["pos"]).length()
				var radius: float = info["radius"]
				if d >= radius:
					continue
				var falloff := 1.0 - d / radius
				level += float(info.get("energy", 1.0)) * falloff * falloff
			map.light_level[i] = clampf(level, 0.0, 1.5)


func light_at(world_pos: Vector2) -> float:
	if map == null:
		return 0.3
	var tile := map.world_to_tile(world_pos)
	if not map.in_bounds(tile.x, tile.y):
		return 0.0
	return float(map.light_level[map.idx(tile.x, tile.y)])


func _process(delta: float) -> void:
	_time += delta
	if _light_sources.is_empty():
		return
	for entry in _light_sources:
		if not entry["flicker"]:
			continue
		var light: PointLight2D = entry["light"]
		var base: float = entry["base"]
		var phase: float = entry["phase"]
		var noise := sin(_time * 17.0 + phase) * sin(_time * 7.3 + phase * 2.0)
		light.energy = base * (0.75 + 0.25 * noise)
	_lightmap_timer += delta
	if _lightmap_timer >= 0.25:
		_lightmap_timer = 0.0
		update_lightmap()
