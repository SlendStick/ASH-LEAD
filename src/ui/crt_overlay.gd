class_name CrtOverlay
extends CanvasLayer
## Full-screen CRT post-processing: scanlines, chromatic aberration, grain,
## vignette, a damage pulse and an alarm heartbeat.
##
## Lives on its own CanvasLayer (layer 5, under the HUD at 20) so the HUD text
## stays crisp while the *world* gets the treatment. Toggle with the settings
## screen; `intensity` 0 disables the shader cost completely (the rect is hidden).

const SHADER_PATH := "res://shaders/crt_scanlines.gdshader"

var rect: ColorRect
var mat: ShaderMaterial
var enabled := true
var damage := 0.0
var alarm := 0.0


func _ready() -> void:
	layer = 5
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		enabled = false
		return
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
	Signals.player_damaged.connect(_on_damage)
	Signals.alarm_changed.connect(_on_alarm)
	apply_settings()


func _on_damage(_amount: float) -> void:
	damage = minf(1.0, damage + 0.45)


func _on_alarm(level: int, _reason: String) -> void:
	alarm = clampf(float(level) / 2.0, 0.0, 1.0)


func apply_settings() -> void:
	if mat == null:
		return
	var cfg: Dictionary = GameFlow.profile.get("video", {})
	enabled = bool(cfg.get("crt", true))
	var strength := float(cfg.get("crt_intensity", 0.55))
	mat.set_shader_parameter("intensity", strength if enabled else 0.0)
	mat.set_shader_parameter("scanline_count", float(cfg.get("scanlines", 480.0)))
	mat.set_shader_parameter("aberration", float(cfg.get("aberration", 0.8)))
	mat.set_shader_parameter("noise_amount", float(cfg.get("grain", 0.045)))
	rect.visible = enabled


func _process(delta: float) -> void:
	if mat == null:
		return
	damage = maxf(0.0, damage - delta * 1.4)
	mat.set_shader_parameter("damage_pulse", damage * 0.8)
	# alarm makes the scanlines roll faster and the vignette pulse
	mat.set_shader_parameter("roll_speed", 0.35 + alarm * 0.9)
	mat.set_shader_parameter("vignette", 0.9 + alarm * 0.35)
