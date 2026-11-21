shader_type canvas_item;
render_mode blend_add;

// Neon bloom for lamps, signs and muzzle flashes. Drawn as a quad with an
// `additive` blend so it lifts everything underneath: wet asphalt, fog, rain.
// The shape is a soft radial falloff with a hot core and an optional
// horizontal "tube" stretch for strip-lights and shop signs.

uniform vec4 light_color : source_color = vec4(1.0, 0.17, 0.84, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 1.6;
uniform float radius : hint_range(0.02, 1.0) = 0.45;
uniform float core : hint_range(0.0, 1.0) = 0.55;
uniform float tube_stretch : hint_range(0.0, 1.0) = 0.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.0, 8.0) = 1.4;

void fragment() {
	vec2 p = UV - vec2(0.5);
	// stretch horizontally for strip lights / signs
	p.x /= mix(1.0, 0.25, tube_stretch);
	float d = length(p) * 2.0;

	// soft body
	float body = smoothstep(radius, 0.0, d);
	body = pow(body, 2.2);
	// hot core
	float hot = smoothstep(radius * core, 0.0, d);

	// cheap flicker: two out-of-phase sines so a dying sign stutters
	float f = 1.0;
	if (flicker > 0.001) {
		float a = sin(TIME * time_scale * 7.3 + d * 12.0);
		float b = sin(TIME * time_scale * 3.1);
		f = mix(1.0, 0.55 + 0.45 * a * b, flicker);
	}
	// heartbeat pulse for alarms
	float p2 = 1.0 + sin(TIME * time_scale * 3.6) * 0.35 * pulse;

	vec3 col = light_color.rgb * (body * intensity + hot * intensity * 2.5) * f * p2;
	float alpha = (body * 0.85 + hot * 0.35) * light_color.a;
	COLOR = vec4(col, alpha);
}
