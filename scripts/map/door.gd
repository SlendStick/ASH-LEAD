class_name Door
extends Node2D
## A door tile that blocks movement and sight while closed.

signal toggled(door: Door, is_open: bool)

var map: MapData
var pos: Vector2i
var open: bool = false
var locked: bool = false
var panel: Sprite2D
var body: StaticBody2D
var shape: CollisionShape2D
var busy_by: Character = null
var duration: float = 0.35


func get_prompt() -> String:
	return Localization.t("close_door") if open else Localization.t("open_door")


func can_use(_character: Character) -> bool:
	return not locked


func start(character: Character) -> void:
	busy_by = character


func complete(_character: Character) -> void:
	toggle()


func cancel(_character: Character) -> void:
	busy_by = null


func setup(map_data: MapData, door_pos: Vector2i, info: Dictionary) -> void:
	map = map_data
	pos = door_pos
	position = map.tile_center_world(pos.x, pos.y)
	open = bool(info.get("open", false))
	locked = bool(info.get("locked", false))
	panel = Sprite2D.new()
	panel.texture = load("res://assets/textures/door.png")
	add_child(panel)
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(MapData.TILE_SIZE, MapData.TILE_SIZE * 0.4)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	var horizontal_passage: bool = map.is_walkable(pos.x - 1, pos.y) and map.is_walkable(pos.x + 1, pos.y)
	if horizontal_passage:
		panel.rotation = PI * 0.5
		shape.rotation = PI * 0.5
	_apply_open()


func _apply_open() -> void:
	shape.disabled = open
	if map != null and map.in_bounds(pos.x, pos.y):
		map.sight_block[map.idx(pos.x, pos.y)] = not open
	var info: Dictionary = map.door_map.get(pos, {})
	info["open"] = open
	map.door_map[pos] = info
	if panel != null:
		panel.modulate = Color(0.65, 1.0, 0.8, 0.85) if open else Color(1, 1, 1, 1)


func set_open(value: bool) -> void:
	if locked or open == value:
		return
	open = value
	_apply_open()
	toggled.emit(self, open)


func toggle() -> void:
	set_open(not open)


func is_blocking_sight() -> bool:
	return not open
