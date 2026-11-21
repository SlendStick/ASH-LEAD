shader_type canvas_item;

// Rain running down glass, used on windows and as a foreground trick during
// cutscenes / the loading screen. Two passes: a slow "droplet trail" mask and a
// fast streak mask, both distorted by a cheap hash field.

uniform vec4 glass_tint : source_color = vec4(0.55, 0.68, 0.85, 0.14);
uniform float drop_density : hint_range(1.0, 60.0) = 22.0;
uniform float drop_speed : hint_range(0.0, 4.0) = 0.9;
uniform float streak_amount : hint_range(0.0, 1.0) = 0.45;
uniform float distortion : hint_range(0.0, 0.05) = 0.012;
uniform float frost : hint_range(0.0, 1.0) = 0.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 grid = vec2(drop_density, drop_density * 0.6);

	// droplet columns: each cell owns one drop falling at its own speed
	vec2 cell = floor(uv * grid);
	float h = hash(cell);
	float speed = drop_speed * (0.4 + h);
	float fall = fract(uv.y * grid.y - TIME * speed + h * 10.0);
	vec2 local = vec2(fract(uv.x * grid.x) - 0.5, fall - 0.5);
	float drop = smoothstep(0.32, 0.0, length(local * vec2(1.0, 1.6)));
	// refract the pane slightly under each drop/slide
	vec2 warp = local * distortion * (drop + 0.4);
	float trail = smoothstep(0.9, 0.0, local.y) * 0.25 * step(0.72, h);

	// fast streaks
	float s = hash(vec2(floor(uv.x * 90.0), floor(uv.y * 5.0 - TIME * 6.0)));
	float streak = smoothstep(0.985, 1.0, s) * streak_amount;

	// frost on the corners of the pane
	float corner = smoothstep(0.55, 0.0, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)) * 3.0);

	vec3 col = glass_tint.rgb + vec3(warp.x, warp.y, 0.0) * 2.0;
	col += vec3(0.85, 0.92, 1.0) * (drop + trail + streak) * 0.55;
	col = mix(col, vec3(0.75, 0.82, 0.95), frost * (1.0 - corner) * 0.35);

	float a = glass_tint.a + (drop * 0.35 + trail * 0.25 + streak * 0.4);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
