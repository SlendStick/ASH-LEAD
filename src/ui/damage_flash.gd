class_name DamageFlash
extends ColorRect
## Full-screen red vignette pulse when the player is hit.

var amount := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(0, 0)
	size = Vector2(2, 2)
	z_index = -1
	color = Color(0.7, 0.0, 0.06, 0.0)


func _process(delta: float) -> void:
	if amount <= 0.0:
		return
	amount = maxf(0.0, amount - delta * 1.6)
	size = Vector2(2, 2)
	color = Color(0.7, 0.0, 0.06, amount * 0.45)
