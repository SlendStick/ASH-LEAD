shader_type canvas_item;

// Wet asphalt / puddle pass for the street layer.
// The whole look rests on two cheap tricks: a moving normal-ish "ripple" field
// that displaces the reflected colour, and a specular streak that slides with
// the light direction, so the neon signs feel like they are reflected in water.

uniform vec4 base_color : source_color = vec4(0.05, 0.05, 0.075, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.25, 0.45, 0.85, 1.0);
uniform float wetness : hint_range(0.0, 1.0) = 0.7;
uniform float ripple_strength : hint_range(0.0, 3.0) = 0.6;
uniform float ripple_scale : hint_range(1.0, 80.0) = 18.0;
uniform float ripple_speed : hint_range(0.0, 3.0) = 0.55;
uniform float streaks : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 0.4) = 0.05;
uniform vec2 light_dir = vec2(-0.7, -0.5);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 24634.6345);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * ripple_speed;

	// two noise layers, one drifting on x, one on y -> puddle shimmer
	float n1 = vnoise(uv * ripple_scale + vec2(t, -t * 0.6));
	float n2 = vnoise(uv * ripple_scale * 2.1 - vec2(t * 0.7, t));
	float ripple = (n1 * 0.65 + n2 * 0.35) - 0.5;

	vec3 col = base_color.rgb;

	// reflection: brighter where the noise slopes towards the light
	float spec = pow(max(0.0, ripple * 1.6 + 0.5), 3.0);
	col += highlight_color.rgb * spec * wetness * ripple_strength * 0.35;

	// long specular streaks, only on wet ground
	float streak = smoothstep(0.55, 1.0, vnoise(vec2(uv.x * 3.0 + t * 0.2, uv.y * 30.0)));
	col += highlight_color.rgb * streak * streaks * wetness * 0.12 * dot(normalize(light_dir), vec2(0.0, -1.0));

	// asphalt grain
	float g = hash(floor(uv * 512.0));
	col += (g - 0.5) * grain;

	COLOR = vec4(col, base_color.a);
}
