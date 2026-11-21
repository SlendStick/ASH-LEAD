class_name OrderWheel
extends Control
## Radial order menu (G). Applies orders to the bots of the local team.

const ORDERS := [
	{"type": GameTypes.OrderType.FOLLOW, "key": "order_follow", "hint": "order_follow_hint"},
	{"type": GameTypes.OrderType.HOLD, "key": "order_hold", "hint": "order_hold_hint"},
	{"type": GameTypes.OrderType.MOVE, "key": "order_move", "hint": "order_move_hint"},
	{"type": GameTypes.OrderType.COVER, "key": "order_cover", "hint": "order_cover_hint"},
	{"type": GameTypes.OrderType.GATHER, "key": "order_gather", "hint": "order_gather_hint"},
	{"type": GameTypes.OrderType.INTERACT, "key": "order_interact", "hint": "order_interact_hint"},
	{"type": GameTypes.OrderType.HELP, "key": "order_help", "hint": "order_help_hint"},
	{"type": GameTypes.OrderType.ESCORT, "key": "order_escort", "hint": "order_escort_hint"},
	{"type": GameTypes.OrderType.STEALTH, "key": "order_stealth", "hint": "order_stealth_hint"},
	{"type": GameTypes.OrderType.FREE, "key": "order_free", "hint": "order_free_hint"},
	{"type": GameTypes.OrderType.CANCEL, "key": "order_cancel", "hint": "order_cancel_hint"},
]

var hud: HUD
var match_ref: Match
var dim: ColorRect
var title: Label
var buttons: Array = []
var hint_label: Label
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	title = Label.new()
	title.text = Localization.t("order_wheel_title")
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(960 - 140, 540 - 250)
	title.custom_minimum_size = Vector2(280, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.position = Vector2(960 - 180, 540 + 210)
	hint_label.custom_minimum_size = Vector2(360, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color(0.7, 0.85, 0.9)
	add_child(hint_label)
	var center := Vector2(960, 540)
	var radius := 185.0
	for i in ORDERS.size():
		var order: Dictionary = ORDERS[i]
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, Localization.t(order["key"])]
		button.custom_minimum_size = Vector2(190, 40)
		button.add_theme_font_size_override("font_size", 16)
		var angle := -PI * 0.5 + TAU * float(i) / float(ORDERS.size())
		var pos := center + Vector2(cos(angle), sin(angle)) * radius - Vector2(95, 20)
		button.position = pos
		button.pressed.connect(_on_order.bind(int(order["type"])))
		add_child(button)
		buttons.append({"button": button, "order": order})


func _on_order(type: int) -> void:
	close()
	if hud != null:
		hud.order_selected.emit(type)


func open() -> void:
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if match_ref != null:
		match_ref.ui_blocking = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	AudioManager.ui_click()


func close() -> void:
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if match_ref != null:
		match_ref.ui_blocking = false
	if hud != null and hud.match_ref != null:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		for i in buttons.size():
			var key := KEY_1 + i if i < 9 else (KEY_0 if i == 9 else KEY_MINUS)
			if event.keycode == key:
				_on_order(int(buttons[i]["order"]["type"]))
				get_viewport().set_input_as_handled()
				return
