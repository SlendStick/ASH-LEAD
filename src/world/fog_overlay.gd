class_name FogOverlay
extends Sprite2D
## Stealth darkness ("fog of war") drawn with shaders/fog_of_war.gdshader.
##
## The overlay is a single map-sized sprite. A low-resolution visibility texture
## (one texel per map tile) is rebuilt a few times per second from the local
## team's line of sight: tiles the team can see are white, everything else black.
## The shader turns that mask into breathing darkness plus grain, so the level
## stays readable but corridors beyond your cone are genuinely black.
##
## This is *visual* fog. Gameplay visibility (who can be shot, who the AI knows
## about) is decided by MatchWorld._tick_visibility; the two use the same tiles
## and LOS helper so they never disagree.

const SHADER_PATH := "res://shaders/fog_of_war.gdshader"
const UPDATE_INTERVAL := 0.2

var map: GeneratedMap
var image: Image
var tex: ImageTexture
var mat: ShaderMaterial
var viewer_team := 0
var eye: Actor = null
var _accum := 0.0
var _cells_visible: Array[bool] = []
var enabled := true


func setup(g: GeneratedMap) -> void:
	map = g
	centered = false
	position = Vector2.ZERO
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image = Image.create(g.w, g.h, false, Image.FORMAT_R8)
	image.fill(Color(1, 1, 1))
	tex = ImageTexture.create_from_image(image)
	texture = tex
	scale = Vector2(GeneratedMap.TILE, GeneratedMap.TILE)
	_cells_visible.resize(g.w * g.h)
	_cells_visible.fill(false)
	var shader: Shader = load(SHADER_PATH)
	if shader != null:
		mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("visibility_tex", tex)
		mat.set_shader_parameter("map_aspect", float(g.w) / float(maxf(1.0, float(g.h))))
		material = mat
	set_process(true)


func set_enabled(v: bool) -> void:
	enabled = v
	visible = v
	set_process(v)


func _process(delta: float) -> void:
	if not enabled or map == null:
		return
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	refresh()


## Rebuild the visibility mask from the current eye (player, spectated actor or
## the team's forward-most bot while dead).
func refresh() -> void:
	if map == null or image == null:
		return
	if eye == null or not is_instance_valid(eye) or eye.dead:
		eye = null
	var origin_cell := Vector2i(-1, -1)
	var facing := 0.0
	var radius := 9.0
	if eye != null:
		origin_cell = map.world_to_cell(eye.global_position)
		facing = eye.facing
		radius = 7.0 + (2.0 if eye.crouching else 0.0)
	else:
		return
	var half_cone := 1.35
	if eye.aiming:
		half_cone = 0.75
		radius += 2.5
	var r := int(ceil(radius))
	var dirty := false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := origin_cell + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= map.w or cell.y >= map.h:
				continue
			var idx := cell.y * map.w + cell.x
			var vis := false
			var dist := Vector2(float(dx), float(dy)).length()
			if dist <= radius and dist > 0.01:
				var ang := Vector2(float(dx), float(dy)).angle()
				var diff := wrapf(ang - facing, -PI, PI)
				vis = absf(diff) <= half_cone
			elif dist <= 0.01:
				vis = true
			if vis and dist > 1.5:
				var t := map.tile_at(cell)
				if t == GeneratedMap.TK_WALL or t == GeneratedMap.TK_VOID:
					vis = false
				elif not Util.los_clear_fast(map, eye.global_position, map.cell_to_world(cell)):
					vis = false
			if _cells_visible[idx] != vis:
				_cells_visible[idx] = vis
				dirty = true
			var v := 255 if vis else 0
			image.set_pixel(cell.x, cell.y, Color8(v, v, v, 255))
	if dirty:
		tex.update(image)


## Small "memory" reveal: an area the team has already explored stays dimly lit.
func reveal_circle(world_pos: Vector2, radius_cells: int) -> void:
	if map == null:
		return
	var c := map.world_to_cell(world_pos)
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			if dx * dx + dy * dy > radius_cells * radius_cells:
				continue
			var cell := c + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= map.w or cell.y >= map.h:
				continue
			var idx := cell.y * map.w + cell.x
			if _cells_visible[idx]:
				continue
			_cells_visible[idx] = true
			image.set_pixel(cell.x, cell.y, Color8(90, 90, 90, 255))
	tex.update(image)


## Union of "seen now" and "remembered", used by the minimap when it wants the
## same knowledge the fog has.
func is_cell_known(cell: Vector2i) -> bool:
	if map == null or cell.x < 0 or cell.y < 0 or cell.x >= map.w or cell.y >= map.h:
		return false
	return _cells_visible[cell.y * map.w + cell.x]
