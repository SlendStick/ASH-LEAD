shader_type canvas_item;

// Animated neon sign / tattooable decal for walls: an emissive tube with a
// glitch cycle. Used by decor_painter on shop fronts, hospital signage, etc.

uniform vec4 sign_color : source_color = vec4(1.0, 0.17, 0.84, 1.0);
uniform vec4 backup_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform float glow : hint_range(0.0, 6.0) = 1.8;
uniform float flicker_chance : hint_range(0.0, 1.0) = 0.35;
uniform float glitch : hint_range(0.0, 1.0) = 0.15;
uniform float speed : hint_range(0.0, 6.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// The sign art comes from the sprite texture; we only modulate emission.
	vec4 tex = texture(TEXTURE, UV);

	// dead-tube cycle: mostly on, occasionally stuttering off
	float t = TIME * speed;
	float window = step(0.92, hash(vec2(floor(t * 1.7), 3.0))) * flicker_chance;
	float stutter = 1.0;
	if (window > 0.5) {
		float f = hash(vec2(floor(t * 24.0), 9.0));
		stutter = mix(1.0, step(0.55, f), window);
	}

	// horizontal glitch slice jumping between the two colours
	float row = floor(UV.y * 48.0);
	float jitter = step(1.0 - glitch * 0.08, hash(vec2(row, floor(t * 9.0))));
	vec3 col = mix(sign_color.rgb, backup_color.rgb, jitter);

	float lum = tex.r;
	vec3 out_col = col * lum * glow * stutter;
	out_col += col * pow(lum, 3.0) * glow * 0.8;
	COLOR = vec4(out_col, tex.a * (0.55 + 0.45 * lum) * stutter);
}
