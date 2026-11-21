extends Control
## Loading screen with generated intel while the match builds.

var t := 0.0
var title: Label
var sub: Label
var intel: Label
var bar: ProgressBar
var lines: Array[String] = []
var line_index := 0
var line_timer := 0.0
var done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.009, 0.024)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var nb := NeonBackground.new()
	nb.modulate = Color(1, 1, 1, 0.25)
	add_child(nb)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 140)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_right", 140)
	margin.add_theme_constant_override("margin_bottom", 110)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	margin.add_child(v)
	var mode_id := str(GameFlow.match_config.get("mode", "heist"))
	var mode: Dictionary = Db.MODES.get(mode_id, Db.MODES["heist"])
	title = UiKit.neon_title(str(mode.get("name", "ОПЕРАЦИЯ")), 56, UiKit.P["magenta"])
	v.add_child(title)
	sub = UiKit.make_label(str(mode.get("tagline", "")), 18, UiKit.P["cyan"])
	v.add_child(sub)
	v.add_child(UiKit.vspace(10))
	var brief := UiKit.make_label(str(mode.get("brief", "")), 15, Color(0.85, 0.85, 0.92, 0.9))
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(900, 0)
	v.add_child(brief)
	v.add_child(UiKit.vspace(16))
	v.add_child(UiKit.make_label("ДОСЬЕ / РАЗВЕДКА", 13, UiKit.P["amber"]))
	intel = UiKit.make_label("", 14, UiKit.P["bone"])
	intel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel.custom_minimum_size = Vector2(900, 120)
	v.add_child(intel)
	v.add_child(UiKit.vspace(10))
	bar = UiKit.make_bar(Color("ff2bd6"), Color(0.06, 0.05, 0.09), 6)
	bar.value = 0.0
	bar.custom_minimum_size = Vector2(900, 6)
	v.add_child(bar)
	var tip := UiKit.make_label("СОВЕТ: " + GameFlow.random_tip(), 12, UiKit.P["grey"])
	v.add_child(tip)
	lines = []
	for i in range(7):
		lines.append("▸ " + Db.INTEL_TAGS[randi_range(0, Db.INTEL_TAGS.size() - 1)])
	lines.append("▸ Полиция приедет через %s" % Util.fmt_time(float(mode.get("police_delay", 0.0))))
	lines.append("▸ Гражданских в здании: %d" % int(mode.get("civilians", 0)))
	lines.append("▸ Ждать подкрепления: нет. Работаем с тем, что есть.")
	set_process(true)
	Ui.fade_from_black(0.4)


func _process(delta: float) -> void:
	t += delta
	bar.value = minf(100.0, float(t) * 58.0)
	line_timer -= delta
	if line_timer <= 0.0 and line_index < lines.size():
		line_timer = 0.16
		intel.text += lines[line_index] + "\n"
		line_index += 1
	if t > 1.9 and not done:
		done = true
		_enter_match()


func _enter_match() -> void:
	var scene: PackedScene = load("res://scenes/match.tscn")
	if scene == null:
		return
	get_tree().change_scene_to_packed(scene)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		GameFlow.back_to_menu()
