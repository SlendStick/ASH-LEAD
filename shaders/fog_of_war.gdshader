shader_type canvas_item;

// Fog of war / stealth darkness.
// The map itself is drawn normally; this quad is laid over the world and each
// actor's visibility writes into a small "visibility" texture (an Image) that
// the world updates at 20 Hz. Everything outside the light cones and near the
// player fades to near-black with a faint cold noise so the darkness breathes.

uniform sampler2D visibility_tex : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.02, 0.015, 0.045, 1.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.92;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.025;
uniform float breath_speed : hint_range(0.0, 2.0) = 0.25;
uniform float reveal_radius : hint_range(0.01, 1.0) = 1.0;
uniform float map_aspect = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float vis = texture(visibility_tex, uv).r;

	// breathing darkness: the fog slowly inhales so it never looks like a
	// static black overlay
	float breath = sin(TIME * breath_speed * 6.2831) * 0.5 + 0.5;
	float d = darkness * mix(0.94, 1.0, breath);

	float a = (1.0 - vis * reveal_radius) * d;
	// fine grain so the fog reads as air, not as a flat fill
	float n = hash(floor(uv * vec2(320.0, 320.0 / map_aspect)) + vec2(TIME * 3.0, 0.0));
	a += (n - 0.5) * noise_amount;

	COLOR = vec4(fog_color.rgb, clamp(a, 0.0, 1.0));
}
