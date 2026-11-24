shader_type canvas_item;
// Pixel art grass sway, driven by the Wind node (world/grass/wind.gd).
//
// Each blade is the white, straight mask from assets/grassblade.png, drawn by
// GrassTuft as 4 stacked slices. This shader moves the slice corners: the root
// stays put and every corner above it slides sideways (more toward the tip),
// so the blade bends in a curve. Nearest filtering keeps it crisp pixel art.
//
// Motion = a left-right sway that travels downwind in waves (blades swing to
// both sides of upright, whatever the wind direction) + a lean toward the side
// the wind blows to + gust waves that roll across the world (the Ghost of
// Tsushima look) + a small per-blade flutter. Strength 0 = straight and still.
// The player parts the grass around their feet.
//
// The Wind node writes every "set by Wind" uniform each frame. The gust math is
// mirrored in Wind.gust_at(), so gameplay code can read the same wind.

// --- Blade sprite layout ---
uniform vec2 texture_size = vec2(32.0, 32.0);
// Root point inside the texture, in texels: center of the base, bottom edge.
// Keep in sync with GrassTuft.BLADE_ROOT.
uniform vec2 blade_root = vec2(16.0, 32.0);
uniform float blade_height = 32.0;

// --- Set by Wind ---
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_phase = 0.0;      // px the gust waves have traveled
uniform float wind_time = 0.0;       // seconds
uniform float wind_strength = 0.7;   // 0..1, fades the gust shine with the wind
uniform float gust_size = 120.0;     // px between gust waves
uniform float base_bend = 2.0;       // px the tip leans in steady wind
uniform float gust_bend = 4.0;       // extra px under a full gust
uniform float sway_px = 2.0;         // left-right swing, each way
uniform float sway_speed = 2.6;
uniform float flutter_px = 0.7;
uniform float flutter_speed = 6.0;
uniform vec2 pusher_pos = vec2(-100000.0, -100000.0);
uniform float push_radius = 14.0;
uniform float push_bend = 6.0;
uniform float max_bend = 14.0;

// --- Look ---
uniform float bend_curve : hint_range(0.8, 3.0) = 1.4;     // 1 = straight lean, higher = stiffer base
uniform float droop : hint_range(0.0, 1.0) = 0.2;          // how much bent blades shorten
// How much north/south wind shows as blades leaning toward or away from the
// camera (they shorten). Low keeps the motion a left-right sway.
uniform float depth_lean : hint_range(0.0, 1.0) = 0.25;
uniform float stiffness_jitter : hint_range(0.0, 0.8) = 0.3;
uniform float min_height : hint_range(0.3, 1.0) = 0.6;     // shortest blade, as a fraction
uniform float root_shade : hint_range(0.0, 0.6) = 0.3;
uniform float tip_light : hint_range(0.0, 0.6) = 0.15;
uniform vec4 shine_color : source_color = vec4(0.87, 0.94, 0.66, 1.0);
uniform float shine_amount : hint_range(0.0, 1.0) = 0.45;
uniform float shine_threshold : hint_range(0.0, 1.0) = 0.6;

varying float v_shine;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 0 = calm, 1 = full gust. Keep in sync with Wind.gust_at().
float gust_at(vec2 p) {
	vec2 perp = vec2(-wind_dir.y, wind_dir.x);
	float a = (dot(p, wind_dir) - wind_phase) / gust_size;
	float b = dot(p, perp) / gust_size;
	float w = sin(a * TAU + sin(b * 2.1 + wind_time * 0.23) * 1.6) * 0.65
			+ sin(a * TAU * 0.53 - b * 1.3 + 1.7) * 0.35;
	return smoothstep(0.2, 0.95, w * 0.5 + 0.5);
}

void vertex() {
	vec2 texel = UV * texture_size;          // this corner, in texels
	vec2 corner = VERTEX - texel;            // the blade's top-left, same for all its slices
	vec2 root = floor((MODEL_MATRIX * vec4(corner + blade_root, 0.0, 1.0)).xy + 0.5);

	float seed = hash(root);
	float stiffness = 1.0 + (seed - 0.5) * 2.0 * stiffness_jitter;
	float height_scale = mix(min_height, 1.0, fract(seed * 7.31));

	// Wind
	float gust = gust_at(root);
	float lean = (base_bend + gust * gust_bend) * stiffness;
	float travel = dot(root, wind_dir) / gust_size * TAU * 0.5;
	float sway = sin(wind_time * sway_speed - travel + seed * 1.2) * sway_px * (0.6 + 0.4 * gust);
	float flutter = sin(wind_time * flutter_speed + seed * TAU) * flutter_px * (0.35 + gust);
	float bend_x = lean * wind_dir.x + sway + flutter;
	float bend_depth = abs(lean * wind_dir.y) * depth_lean;

	// Player parts the grass (top-down: depth counts double so it hugs the feet).
	vec2 away = root - pusher_pos;
	float push = 1.0 - clamp(length(away * vec2(1.0, 2.0)) / push_radius, 0.0, 1.0);
	push = push * push * (3.0 - 2.0 * push);
	bend_x += (away.x < 0.0 ? -1.0 : 1.0) * push * push_bend;
	bend_depth += push * push_bend * 0.4;
	bend_x = clamp(bend_x, -max_bend, max_bend);

	// Shorter when bent, and each blade gets its own height.
	float sink = clamp(droop * (abs(bend_x) * 0.5 + bend_depth) / blade_height, 0.0, 0.5);
	float squash = height_scale * (1.0 - sink);

	float up = max(blade_root.y - texel.y, 0.0);       // px above the root, 0 at the base
	float along = clamp(up / blade_height, 0.0, 1.0);
	VERTEX.x += bend_x * pow(along, bend_curve);
	VERTEX.y += up * (1.0 - squash);                    // pull toward the root

	v_shine = gust * clamp(wind_strength * 1.5, 0.0, 1.0);
}

void fragment() {
	// COLOR arrives as texture * layer color (the mask is white).
	float row = floor(UV.y * texture_size.y);
	float along = clamp((blade_root.y - 1.0 - row) / blade_height, 0.0, 1.0);
	vec3 col = COLOR.rgb;
	if (along < 0.12) {
		col *= 1.0 - root_shade;
	} else if (along > 0.72) {
		col = mix(col, vec3(1.0), tip_light);
	}
	if (v_shine > shine_threshold && along > 0.45) {
		float strong = v_shine > mix(shine_threshold, 1.0, 0.6) ? 1.0 : 0.55;
		col = mix(col, shine_color.rgb, shine_amount * strong);
	}
	COLOR.rgb = col;
}
