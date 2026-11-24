shader_type canvas_item;
render_mode blend_mul, unshaded;
// Cloud shadows drifting over a map section, driven by the Wind node
// (world/grass/wind.gd). Used by CloudShadows (world/weather/cloud_shadows.gd),
// which draws one rect over the whole map with this material.
//
// The rect multiplies whatever is under it: white = no change, shadow_color
// inside a cloud. Every pixel is either fully in shadow or fully lit, and the
// soft cloud edge becomes an ordered (Bayer) dither, so the result stays crisp
// pixel art over grass, sand, buildings and characters alike.
//
// Cloud shapes come from layered value noise in world space. A slow domain
// warp makes them change shape as they drift.

// --- Set by Wind ---
uniform vec2 cloud_offset = vec2(0.0);   // px the clouds have drifted
uniform float cloud_time = 0.0;          // seconds

group_uniforms Look;
// Multiplied into everything under a cloud. A cool tint reads as sky shade.
uniform vec4 shadow_color : source_color = vec4(0.74, 0.79, 0.90, 1.0);
// A second, deeper shade in the thick middle of clouds (white = off).
uniform vec4 core_color : source_color = vec4(0.66, 0.72, 0.86, 1.0);
// Size of one cloud, roughly, in px.
uniform float cloud_size_px : hint_range(40.0, 600.0) = 170.0;
// Share of the ground under clouds.
uniform float coverage : hint_range(0.0, 1.0) = 0.42;
// Width of the dithered edge. 0 = hard edge.
uniform float softness : hint_range(0.0, 0.3) = 0.022;
// How much deeper inside a cloud the core starts. Higher = smaller core.
uniform float core_inset : hint_range(0.0, 0.5) = 0.09;
// Clouds are this many times wider than tall.
uniform float stretch : hint_range(1.0, 3.0) = 1.5;
// How fast clouds change shape as they drift.
uniform float morph_speed : hint_range(0.0, 0.5) = 0.04;
// Size of one dither pixel, for chunkier edges.
uniform float dither_px : hint_range(1.0, 4.0, 1.0) = 1.0;

varying vec2 v_world;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.4);
		amp *= 0.5;
	}
	return total / 0.9375;
}

// 4x4 ordered dither threshold for this pixel, 0..1.
float bayer4(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[x + y * 4] + 0.5) / 16.0;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cell = floor(v_world / dither_px);
	vec2 px = cell * dither_px;
	vec2 uv = (px - cloud_offset) / cloud_size_px;
	uv.x /= stretch;
	float t = cloud_time * morph_speed;
	vec2 warp = vec2(fbm(uv * 0.7 + vec2(t, 3.1)), fbm(uv * 0.7 + vec2(5.2, -t)));
	float n = fbm(uv + (warp - 0.5) * 0.9);

	float edge = mix(0.72, 0.30, coverage);
	float threshold = bayer4(cell);
	float shade = clamp((n - edge) / max(softness, 0.001) * 0.5 + 0.5, 0.0, 1.0);
	float core = clamp((n - edge - core_inset) / max(softness, 0.001) * 0.5 + 0.5, 0.0, 1.0);

	vec3 col = vec3(1.0);
	if (threshold < core) {
		col = core_color.rgb;
	} else if (threshold < shade) {
		col = shadow_color.rgb;
	}
	COLOR = vec4(col, 1.0);
}
