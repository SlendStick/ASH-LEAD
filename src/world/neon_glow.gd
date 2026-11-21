class_name NeonGlow
extends Node2D
## One additive neon light rendered with shaders/neon_bloom.gdshader.
##
## A Node2D that owns a single quad (via `_draw` -> `draw_rect`? no: a shader
## needs a canvas item with a material, so this node IS the canvas item). The
## quad is sized to 2x the light radius; the shader does the radial falloff, the
## hot core, the flicker and the alarm pulse on the GPU.

const SHADER_PATH := "res://shaders/neon_bloom.gdshader"

var color := Color(0.2, 0.8, 1.0)
var radius := 180.0
var intensity := 1.5
var tube := 0.0
var flicker := 0.0
var pulse := 0.0
var mat: ShaderMaterial
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		return
	mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat
	z_index = 0
	_seed = randf() * 10.0
	_apply()


func setup(light_color: Color, light_radius: float, light_power: float = 1.0) -> void:
	color = light_color
	radius = light_radius
	intensity = clampf(light_power * 1.6, 0.2, 5.0)
	_apply()


func set_alarm_pulse(p: float) -> void:
	if is_equal_approx(p, pulse):
		return
	pulse = p
	if mat != null:
		mat.set_shader_parameter("pulse", pulse)


func set_enabled(v: bool) -> void:
	visible = v
	set_process(v)


func _apply() -> void:
	if mat == null:
		return
	mat.set_shader_parameter("light_color", color)
	mat.set_shader_parameter("radius", clampf(radius / 340.0, 0.05, 1.0))
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("core", 0.45)
	mat.set_shader_parameter("tube_stretch", tube)
	mat.set_shader_parameter("flicker", flicker)


func _draw() -> void:
	var s := radius / 170.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_rect(Rect2(-170, -170, 340, 340), Color.WHITE, true)


func _process(delta: float) -> void:
	_t += delta
	# only the flicker lives on the CPU: cheap, and lets dying tubes stutter
	if flicker > 0.0 and mat != null:
		var f := 1.0
		if sin(_t * 11.0 + _seed) > 0.96:
			f = 0.2
		mat.set_shader_parameter("intensity", intensity * f)
