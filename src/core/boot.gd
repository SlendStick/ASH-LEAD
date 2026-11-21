extends Node
## Entry point: shows a short studio ident then loads the main menu.

var t := 0.0
var started := false
var logo: Label
var sub: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.008, 0.022, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	layer.add_child(box)
	logo = UiKit.neon_title("ASH&LEAD", 78, UiKit.P["magenta"])
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)
	sub = UiKit.make_label("ПРЕСТУПЛЕНИЕ · ПРАВОПОРЯДОК · НЕОН", 14, UiKit.P["cyan"])
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	logo.modulate.a = 0.0
	sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.5)
	tw.tween_property(sub, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.9)
	tw.tween_callback(_go)


func _go() -> void:
	if started:
		return
	started = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
