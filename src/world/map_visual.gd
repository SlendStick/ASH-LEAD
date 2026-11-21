class_name MapVisual
extends Node2D
## Renders a GeneratedMap as neon-noir artwork and owns its gameplay layers.
##
## Everything is drawn procedurally (no external art): floor plates with wet
## reflections, walls with emissive trims, cracked glass, doors, neon signs, props
## silhouettes, blood and shell decals, fog patches, volumetric god-rays. The
## static layer is baked into a SubViewport once, then only animated overlays
## (lights, rain, fog, decals) redraw.

const T := GeneratedMap.TILE

var map: GeneratedMap
var floors_root: Node2D
var walls_body: StaticBody2D
var decor_root: Node2D
var decals: Node2D
var fog_patches: Node2D
var lights_layer: Node2D
var rain: Node2D
var blood_shader_mat: ShaderMaterial
var static_baked := false
var floor_painter: Node2D = null
var time := 0.0

var _rng := RandomNumberGenerator.new()


func setup(g: GeneratedMap) -> void:
	map = g
	_rng.seed = g.seed_value
	_ensure_layers()
	_build_floor()
	_build_walls()
	_build_decor()
	_build_fog()
	_build_lights()
	_build_rain()
	_build_physics_bounds()
	_apply_floor_shader()


## Wet-asphalt shading for the street tile layer. The floor painter bakes its
## own colours; this material adds the puddle shimmer and the specular slide so
## neon signs feel reflected in the road.
func _apply_floor_shader() -> void:
	var shader: Shader = load("res://shaders/wet_asphalt.gdshader")
	if shader == null or floor_painter == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("wetness", 0.7)
	mat.set_shader_parameter("ripple_scale", 21.0)
	mat.set_shader_parameter("streaks", 0.45)
	floor_painter.material = mat


func _ensure_layers() -> void:
	floors_root = Node2D.new()
	floors_root.name = "Floors"
	floors_root.z_index = -40
	add_child(floors_root)
	decals = Node2D.new()
	decals.name = "Decals"
	decals.z_index = -30
	add_child(decals)
	decor_root = Node2D.new()
	decor_root.name = "Decor"
	decor_root.z_index = -20
	add_child(decor_root)
	fog_patches = Node2D.new()
	fog_patches.name = "Fog"
	fog_patches.z_index = 40
	add_child(fog_patches)
	lights_layer = Node2D.new()
	lights_layer.name = "Lights"
	lights_layer.z_index = 35
	lights_layer.set_script(load("res://src/world/lights_layer.gd"))
	add_child(lights_layer)
	walls_body = StaticBody2D.new()
	walls_body.name = "WallsBody"
	walls_body.collision_layer = 1
	walls_body.collision_mask = 0
	add_child(walls_body)
	rain = Node2D.new()
	rain.name = "Rain"
	rain.z_index = 70
	add_child(rain)


func _build_floor() -> void:
	var paint := FloorPainter.new()
	paint.map = map
	paint.position = Vector2.ZERO
	floors_root.add_child(paint)
	floor_painter = paint


func _build_walls() -> void:
	var paint := WallPainter.new()
	paint.map = map
	walls_body.add_child(paint)


func _build_decor() -> void:
	var decor := DecorPainter.new()
	decor.map = map
	decor_root.add_child(decor)


func _build_fog() -> void:
	var fog := FogPainter.new()
	fog.map = map
	fog.z_index = 0
	fog_patches.add_child(fog)


func _build_lights() -> void:
	lights_layer.set("map", map)
	lights_layer.set("visual", self)
	lights_layer.call("build")


func _build_rain() -> void:
	rain.set_script(load("res://src/world/rain_layer.gd"))
	rain.set("map", map)
	rain.call("build")
	rain.z_index = 70


## One StaticBody2D for the whole level: consecutive solid tiles per row are
## merged into a single box collider, so a 100x100 map costs a few hundred shapes
## instead of ten thousand nodes (and doors can add/remove one at runtime).
func _build_physics_bounds() -> void:
	if walls_body == null:
		walls_body = StaticBody2D.new()
		walls_body.name = "WallsBody"
		walls_body.collision_layer = 1
		walls_body.collision_mask = 0
		add_child(walls_body)
	var old_rects := walls_body.get_children()
	for r in old_rects:
		walls_body.remove_child(r)
		r.queue_free()
	var box := {}
	for y in range(0, map.h):
		var run_start := -1
		for x in range(0, map.w + 1):
			var solid := false
			if x < map.w:
				var t := map.tile_at(Vector2i(x, y))
				solid = t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_WINDOW or t == GeneratedMap.TK_CRATE
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				var width := x - run_start
				var key := "%d_%d" % [width, y]
				if not box.has(key):
					var rect := RectangleShape2D.new()
					rect.size = Vector2(width * GeneratedMap.TILE, GeneratedMap.TILE)
					box[key] = rect
				var cs := CollisionShape2D.new()
				cs.shape = box[key]
				cs.position = Vector2((run_start + width * 0.5) * GeneratedMap.TILE, (y + 0.5) * GeneratedMap.TILE)
				walls_body.add_child(cs)
				run_start = -1


## Door helper: seal or unseal one tile so walking, LOS and pathing all agree.
func set_tile_solid(cell: Vector2i, solid: bool) -> void:
	if map == null:
		return
	var t := map.tile_at(cell)
	if solid:
		if t == GeneratedMap.TK_FLOOR or t == GeneratedMap.TK_DOOR:
			map.set_tile_cell(cell, GeneratedMap.TK_WALL)
	else:
		if t == GeneratedMap.TK_WALL:
			map.set_tile_cell(cell, GeneratedMap.TK_DOOR)
	map.refresh_cell(cell)
	_build_physics_bounds()


func _process(delta: float) -> void:
	time += delta
	if rain != null and rain.has_method("tick"):
		rain.call("tick", delta)
	if lights_layer != null and lights_layer.has_method("tick"):
		lights_layer.call("tick", delta)


## Blood decal that persists for the whole round (Hatred-grade mess).
func add_blood(pos: Vector2, dir: Vector2, amount: float) -> void:
	var d := BloodDecal.new()
	d.position = pos
	d.amount = clampf(amount, 0.2, 3.0)
	d.dir = dir.normalized()
	d.rot = dir.angle()
	d.z_index = -25
	decals.add_child(d)
	while decals.get_child_count() > 260:
		var old := decals.get_child(0)
		decals.remove_child(old)
		old.queue_free()


func add_shell(pos: Vector2, dir: Vector2) -> void:
	var s := ShellDecal.new()
	s.position = pos
	s.dir = dir
	s.rot = _rng.randf_range(0.0, TAU)
	s.z_index = -24
	decals.add_child(s)


func add_bullet_hole(pos: Vector2, normal: Vector2) -> void:
	var h := HoleDecal.new()
	h.position = pos
	h.rot = normal.angle()
	h.z_index = -23
	decals.add_child(h)


func add_scorch(pos: Vector2, radius: float) -> void:
	var s := ScorchDecal.new()
	s.position = pos
	s.radius = radius
	s.z_index = -26
	decals.add_child(s)


func room_center(room_index: int) -> Vector2:
	if room_index < 0 or room_index >= map.rooms.size():
		return map.world_size() * 0.5
	var r: Rect2i = map.rooms[room_index]["rect"]
	return Vector2(r.position + r.size / 2) * T
