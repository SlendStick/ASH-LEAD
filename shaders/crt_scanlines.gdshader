shader_type canvas_item;

// CRT / scanline / chromatic-aberration post pass.
// Cheap on purpose: the game is a top-down 2D neon-noir, the CRT look is a
// full-screen CanvasLayer ColorRect with this material, NOT a 3D stack.
// Uniforms are animated from UiKit/CrtOverlay so the look can be tuned live.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float scanline_count : hint_range(80.0, 1200.0) = 480.0;
uniform float aberration : hint_range(0.0, 4.0) = 0.8;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.045;
uniform float roll_speed : hint_range(0.0, 3.0) = 0.35;
uniform float damage_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.85, 0.92, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// subtle barrel: push pixels outward from the centre
	vec2 c = uv - vec2(0.5);
	float r2 = dot(c, c);
	vec2 warped = uv + c * r2 * 0.035 * intensity;

	// chromatic aberration: sample R and B slightly apart
	float ab = aberration * 0.0012 * (1.0 + r2);
	vec3 col;
	col.r = texture(screen_tex, warped + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, warped).g;
	col.b = texture(screen_tex, warped - vec2(ab, 0.0)).b;

	// scanlines: dark every other band + a slow rolling bright band
	float line = sin(warped.y * scanline_count * 3.14159);
	float scan = 1.0 - abs(line) * 0.16 * intensity;
	col *= scan;
	float roll = fract(warped.y * 0.6 - TIME * roll_speed);
	float band = smoothstep(0.0, 0.06, roll) * smoothstep(0.22, 0.05, roll);
	col += vec3(0.05, 0.08, 0.12) * band * intensity;

	// sensor noise
	float n = hash(warped * 512.0 + vec2(TIME * 37.0, TIME * 61.0));
	col += (n - 0.5) * noise_amount;

	// vignette
	float vig = smoothstep(0.85, 0.25, r2 * vignette);
	col *= mix(1.0, vig, vignette * 0.85);

	// damage pulse tints the frame blood red
	col = mix(col, vec3(0.55, 0.02, 0.06), damage_pulse * 0.55);
	col *= tint.rgb;

	COLOR = vec4(col, 1.0);
}
