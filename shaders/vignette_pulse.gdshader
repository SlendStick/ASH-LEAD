shader_type canvas_item;

// Low-key noir vignette with a heartbeat pulse for alarm states and low health.
// Sits above the world, below the HUD (CanvasLayer 5..10).

uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength : hint_range(0.0, 1.5) = 0.85;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.2;
uniform vec4 pulse_color : source_color = vec4(0.7, 0.02, 0.08, 1.0);
uniform float grain : hint_range(0.0, 0.2) = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c * vec2(1.0, 0.9)) * 1.7;
	float v = smoothstep(0.55, 1.25, d) * strength;

	// heartbeat: double-thump envelope
	float beat = pow(max(0.0, sin(TIME * pulse_speed * 3.14159)), 6.0);
	float thump = max(beat, pow(max(0.0, sin((TIME + 0.18) * pulse_speed * 3.14159)), 10.0) * 0.6);
	float p = pulse * thump;

	float n = hash(floor(UV * 640.0) + vec2(TIME * 11.0, TIME * 7.0));
	float a = v + p * 0.35 + (n - 0.5) * grain;
	vec3 col = mix(edge_color.rgb, pulse_color.rgb, p);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
