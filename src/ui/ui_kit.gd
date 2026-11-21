class_name UiKit
extends RefCounted
## Neon-noir design system: every screen is built from these helpers so the whole
## game shares one look. Cold blue night, acid green, magenta advertising, blood
## red accents, heavy black, thin glitch lines.

const P := {
	"void": Color(0.0275, 0.0157, 0.051),
	"asphalt": Color(0.0627, 0.0627, 0.098),
	"concrete": Color(0.1137, 0.1098, 0.1686),
	"steel": Color(0.1686, 0.1647, 0.2392),
	"fog": Color(0.098, 0.0706, 0.1961),
	"blue": Color(0.1137, 0.4196, 1.0),
	"cyan": Color(0.2078, 0.7882, 1.0),
	"ice": Color(0.749, 0.9373, 1.0),
	"green": Color(0.1686, 1.0, 0.6039),
	"acid": Color(0.7137, 1.0, 0.1686),
	"magenta": Color(1.0, 0.1686, 0.8392),
	"violet": Color(0.5529, 0.1686, 1.0),
	"red": Color(1.0, 0.1216, 0.2941),
	"blood": Color(0.4784, 0.0, 0.0863),
	"amber": Color(1.0, 0.6902, 0.1686),
	"bone": Color(0.9098, 0.8902, 0.8353),
	"grey": Color(0.4824, 0.4706, 0.5647),
}


static func font(size: int, bold: bool = false) -> Font:
	var f := ThemeDB.fallback_font
	if bold:
		return ThemeDB.fallback_font
	return f


static func make_label(text: String, size: int = 18, color: Color = P["bone"], uppercase: bool = false) -> Label:
	var l := Label.new()
	l.text = text.to_upper() if uppercase else text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func spaced_label(text: String, size: int = 16, color: Color = P["grey"]) -> Label:
	var l := make_label(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func stylebox(bg: Color, border: Color, border_w: int = 1, radius: int = 2, glow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	if glow:
		sb.shadow_color = Color(border.r, border.g, border.b, 0.35)
		sb.shadow_size = 8
	return sb


static func make_button(text: String, accent: Color = P["magenta"], size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", P["bone"])
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", stylebox(Color(0.04, 0.03, 0.07, 0.82), Color(accent.r, accent.g, accent.b, 0.35), 1, 2))
	b.add_theme_stylebox_override("hover", stylebox(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.92), accent, 2, 2, true))
	b.add_theme_stylebox_override("pressed", stylebox(Color(accent.r * 0.3, accent.g * 0.3, accent.b * 0.3, 0.95), Color.WHITE, 2, 2))
	b.add_theme_stylebox_override("focus", stylebox(Color(0, 0, 0, 0.0), Color(accent.r, accent.g, accent.b, 0.6), 1, 2))
	b.add_theme_stylebox_override("disabled", stylebox(Color(0.05, 0.05, 0.06, 0.5), Color(0.2, 0.2, 0.22, 0.5), 1, 2))
	b.mouse_entered.connect(func() -> void: Sfx.play_ui("ui_hover"))
	b.pressed.connect(func() -> void: Sfx.play_ui("ui_click"))
	return b


static func make_small_button(text: String, accent: Color = P["cyan"]) -> Button:
	var b := make_button(text, accent, 14)
	b.custom_minimum_size = Vector2(0, 34)
	return b


static func make_panel(bg: Color = Color(0.035, 0.028, 0.06, 0.92), border: Color = Color(0.35, 0.2, 0.5, 0.5), border_w: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(bg, border, border_w, 3))
	return p


static func make_separator(color: Color = Color(1, 1, 1, 0.08)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func make_bar(fill: Color, bg: Color = Color(0.08, 0.07, 0.1, 0.9), height: int = 8) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.max_value = 100.0
	pb.value = 100.0
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = fill
	sbf.corner_radius_top_left = 1
	sbf.corner_radius_bottom_right = 1
	pb.add_theme_stylebox_override("fill", sbf)
	var sbb := StyleBoxFlat.new()
	sbb.bg_color = bg
	pb.add_theme_stylebox_override("background", sbb)
	return pb


static func neon_title(text: String, size: int = 64, color: Color = P["magenta"], spacing: int = 6) -> Label:
	var l := make_label(text, size, color)
	l.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	# a wide outline is what makes the neon sign read at 56px; glow comes from
	# the shader stack, not from a nonexistent shadow_outline_size constant
	l.add_theme_color_override("font_outline_color", Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.55))
	l.add_theme_constant_override("outline_size", maxi(6, int(size * 0.22)))
	return l


static func make_slider(value: float, min_v: float = 0.0, max_v: float = 1.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(180, 22)
	return s


static func make_option(items: Array, selected: int = 0) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	if selected >= 0 and selected < items.size():
		o.select(selected)
	o.add_theme_font_size_override("font_size", 15)
	o.add_theme_color_override("font_color", P["bone"])
	o.add_theme_stylebox_override("normal", stylebox(Color(0.06, 0.05, 0.09, 0.9), Color(0.4, 0.3, 0.55, 0.6)))
	o.add_theme_stylebox_override("hover", stylebox(Color(0.1, 0.08, 0.14, 0.95), P["magenta"]))
	return o


static func vspace(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hspace(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hline(width: int, color: Color = Color(0.3, 0.2, 0.45, 0.5)) -> Control:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(width, 1)
	return c


static func tag(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stylebox(Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.7), color, 1, 1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := make_label(text, 12, color)
	p.add_child(l)
	return p
