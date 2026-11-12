shader_type canvas_item;
// EarthBound-style animated battle background (GDD 03, "Battle backgrounds").
// A procedural pattern posterized into four palette steps that cycle over time,
// with per-line horizontal waves and a slow scroll. Settings come from
// BattleBackgroundPreset, so one shader makes many looks.

uniform vec4 color_a : source_color = vec4(0.106, 0.078, 0.275, 1.0);
uniform vec4 color_b : source_color = vec4(0.357, 0.165, 0.431, 1.0);
uniform vec4 color_c : source_color = vec4(0.851, 0.341, 0.478, 1.0);
uniform vec4 color_d : source_color = vec4(1.0, 0.635, 0.361, 1.0);
uniform float pattern_scale = 6.0;
uniform float cycle_speed = 0.15;
uniform vec2 scroll = vec2(0.01, 0.02);
uniform float wave_x_amplitude = 0.03;
uniform float wave_x_frequency = 18.0;
uniform float wave_y_amplitude = 0.01;
uniform float wave_y_frequency = 9.0;
uniform float wave_speed = 1.4;
uniform vec2 resolution = vec2(256.0, 224.0);

void fragment() {
	vec2 px = floor(UV * resolution) / resolution; // lock to native pixels
	float t = TIME;
	vec2 uv = px;
	uv.x += sin(px.y * wave_x_frequency + t * wave_speed) * wave_x_amplitude;
	uv.y += sin(px.x * wave_y_frequency + t * wave_speed * 0.7) * wave_y_amplitude;
	uv += scroll * t;

	vec2 p = uv * pattern_scale;
	float bumps = sin(p.x * 3.14159) * sin(p.y * 3.14159);
	float diamonds = abs(fract(p.x + p.y) - 0.5) + abs(fract(p.x - p.y) - 0.5);
	float value = fract(diamonds * 0.8 + bumps * 0.25 + t * cycle_speed);

	int step_index = int(floor(value * 4.0));
	vec4 col = color_d;
	if (step_index == 0) {
		col = color_a;
	} else if (step_index == 1) {
		col = color_b;
	} else if (step_index == 2) {
		col = color_c;
	}
	COLOR = col;
}
