shader_type canvas_item;
// Wind folds for flat grass tiles, driven by the Wind node (world/grass/wind.gd).
//
// Put this on a grass TileMapLayer (Inspector > CanvasItem > Material, or use
// world/grass/wind_streaks_material.tres). Long, thin, dark bands lie across the
// field at a right angle to the wind and roll downwind, like the folds a gust
// pushes through a sea of grass in 3D. Each band is a long thin parallelogram
// that tapers toward its ends, with a bright line on its downwind side (the lit
// face of the fold) and a soft mid-green back edge. Ordered dither softens both
// sides: a light glow ahead of the fold and a mid-green trail behind it.
//
// Bands fade in, roll along for a while, then fade out, and new ones take their
// place. They swell inside gusts and thin out in calm air. Bands only cover
// opaque tile pixels and swap whole colors (no blending), so the result stays on
// your palette and sand paths stay clean.
//
// The Wind node writes every "set by Wind" uniform each frame, using the same
// gust wave as the grass sway shader.

// --- Set by Wind ---
uniform vec2 wind_dir = vec2(1.0, 0.0);   // with the slow natural drift, for gusts
uniform vec2 band_dir = vec2(1.0, 0.0);   // the set direction, for laying out bands
uniform float wind_phase = 0.0;           // px the gust waves have traveled
uniform float wind_time = 0.0;            // seconds
uniform float wind_strength = 0.7;        // 0..1
uniform float gust_size = 120.0;          // px between gust waves
uniform float gustiness = 1.0;            // 0..2

group_uniforms Colors;
// The fold itself: grass pressed down, showing its darker side.
uniform vec4 fold_color : source_color = vec4(0.365, 0.624, 0.384, 1.0);
// The back (upwind) edge of a fold, so it melts into the field.
uniform vec4 back_color : source_color = vec4(0.518, 0.765, 0.392, 1.0);
uniform int back_px : hint_range(0, 3) = 1;
// The lit line on the downwind side of a fold.
uniform vec4 shine_color : source_color = vec4(0.702, 0.918, 0.451, 1.0);
uniform int shine_px : hint_range(0, 3) = 1;
// Empty px between the fold and its lit line.
uniform int shine_gap_px : hint_range(0, 4) = 1;
// The lit line shows only on folds at least this thick.
uniform float shine_min_thickness : hint_range(1.0, 8.0) = 3.0;

group_uniforms Dither;
// A soft glow of light pixels ahead of each fold (downwind of the lit line),
// thinning out with distance in an ordered (Bayer) dither pattern.
uniform vec4 glow_color : source_color = vec4(0.702, 0.918, 0.451, 1.0);
uniform int glow_px : hint_range(0, 12) = 5;
// A short trail of mid-green pixels behind each fold (upwind), same pattern.
uniform int trail_px : hint_range(0, 12) = 4;
// 1 = full dither next to the fold. Lower = sparser. Thick folds get the most.
uniform float dither_strength : hint_range(0.0, 1.0) = 0.75;

group_uniforms Shape;
// Band length in px, shortest and longest.
uniform vec2 length_px = vec2(120.0, 320.0);
// Thickness in px at the widest point, thinnest and thickest band.
uniform vec2 thickness_px = vec2(3.0, 8.0);
// 1 = tapers evenly to both ends (lens). Higher = one end stays thick and the
// other runs thin (wedge, like a long parallelogram). Each band picks a side.
uniform float taper_skew : hint_range(1.0, 4.0) = 2.2;
// Bands bend gently along their length: how far, and over how many px.
uniform float wave_px : hint_range(0.0, 12.0) = 1.5;
uniform float wave_length_px : hint_range(20.0, 400.0) = 260.0;
// Turn the bands away from square-on to the wind, in degrees. They still roll
// downwind.
uniform float tilt_degrees : hint_range(-60.0, 60.0) = 0.0;

group_uniforms Amount;
// Distance between rows of bands, along the wind, in px.
uniform float spacing_px : hint_range(16.0, 200.0, 1.0) = 70.0;
// Room for one band along each row, in px. Keep it above length_px's max / 1.5.
uniform float lane_px : hint_range(40.0, 400.0, 1.0) = 230.0;
// Share of slots that hold a band.
uniform float density : hint_range(0.0, 1.0) = 0.6;
// How thick bands stay outside gusts, as a share of full (0 = only in gusts).
uniform float calm_share : hint_range(0.0, 1.0) = 0.7;
// How far a band rolls before it has faded in and out, in px.
uniform float life_px : hint_range(20.0, 600.0) = 300.0;
// Speed relative to the gust waves. Below 1 the gusts overtake the bands, so
// bands swell and shrink as gusts pass through them.
uniform float speed_scale : hint_range(0.1, 3.0) = 0.8;
group_uniforms;

varying vec2 v_world;

// 4x4 ordered dither threshold for this pixel, 0..1.
float bayer4(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	int i = x + y * 4;
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// 0 = calm, 1 = full gust. Same as gust_at() in grass_sway.gdshader and Wind.gust_at().
float gust_at(vec2 p) {
	vec2 perp = vec2(-wind_dir.y, wind_dir.x);
	float a = (dot(p, wind_dir) - wind_phase) / gust_size;
	float b = dot(p, perp) / gust_size;
	float w = sin(a * TAU + sin(b * 2.1 + wind_time * 0.23) * 1.6) * 0.65
			+ sin(a * TAU * 0.53 - b * 1.3 + 1.7) * 0.35;
	return smoothstep(0.2, 0.95, w * 0.5 + 0.5);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// COLOR arrives as tile texture * modulate.
	if (COLOR.a > 0.5 && wind_strength > 0.001) {
		vec2 dir = normalize(band_dir);
		float tilt = radians(tilt_degrees);
		// across = the band's normal, along = the band's length.
		vec2 across = vec2(dir.x * cos(tilt) - dir.y * sin(tilt), dir.x * sin(tilt) + dir.y * cos(tilt));
		vec2 along = vec2(-across.y, across.x);

		vec2 px = floor(v_world) + 0.5;
		float clock = wind_phase * speed_scale;
		// Coordinates that roll with the bands.
		float u = dot(px, across) - clock * dot(dir, across);
		float v = dot(px, along);
		float strength_k = clamp(wind_strength * 1.4, 0.0, 1.0);
		float row_home = floor(u / spacing_px);
		float lane_home = floor(v / lane_px);
		float threshold = bayer4(floor(v_world));
		// 0 = none, 1 = glow dither, 2 = trail dither, 3 = shine, 4 = back edge, 5 = fold
		int hit = 0;

		for (int i = -1; i <= 1; i++) {
			float row = row_home + float(i);
			for (int j = -2; j <= 0; j++) {
				float lane = lane_home + float(j);
				vec3 slot = vec3(row, lane, 0.0);
				// Each slot plays bands one after another; `age` runs 0..1 per band.
				float life = life_px * (0.7 + 0.6 * hash3(slot + 3.1));
				float t = clock / life + hash3(slot + 5.7);
				float cycle = floor(t);
				float age = t - cycle;
				vec3 k = vec3(row, lane, cycle);
				if (hash3(k + 1.3) >= density) {
					continue;
				}
				float len = mix(length_px.x, length_px.y, hash3(k + 2.9));
				float start = lane * lane_px + hash3(k + 4.4) * max(lane_px * 1.5 - len, 0.0);
				float s = (v - start) / len;           // 0..1 along the band
				if (s <= 0.0 || s >= 1.0) {
					continue;
				}
				// Taper: lens or wedge, thick end on a random side.
				float sk = hash3(k + 6.6) < 0.5 ? s : 1.0 - s;
				float skew = mix(1.0, taper_skew, hash3(k + 7.2));
				float shape = sqrt(sin(PI * pow(sk, skew)));
				// Fade in and out at the start and end of its life, swell in gusts.
				float fade = clamp(sin(PI * age) * 2.5, 0.0, 1.0);
				float g = clamp(gust_at(px) * gustiness, 0.0, 1.0);
				float thick = mix(thickness_px.x, thickness_px.y, hash3(k + 8.8));
				thick = floor(thick * shape * fade * mix(calm_share, 1.0, g) * strength_k + 0.5);
				if (thick < 1.0) {
					continue;
				}
				// Distance behind the band's downwind edge, in px.
				float edge = row * spacing_px + hash3(k + 9.9) * spacing_px * 0.6
						+ sin(v / wave_length_px * TAU + hash3(k + 10.4) * TAU) * wave_px;
				float d = floor(edge - u + 0.5);
				float bold = dither_strength * clamp(thick / max(thickness_px.y, 1.0), 0.0, 1.0);
				float lead = float(shine_gap_px + shine_px);
				if (d >= 0.0 && d < thick) {
					hit = max(hit, d >= thick - float(back_px) && thick > float(back_px) ? 4 : 5);
				} else if (d < -float(shine_gap_px) && d >= -lead && thick >= shine_min_thickness) {
					hit = max(hit, 3);
				} else if (d < -lead && d >= -lead - float(glow_px)) {
					// Ahead of the fold: denser near it, thinning out downwind.
					float fall = 1.0 - (-lead - d - 1.0) / float(max(glow_px, 1));
					if (threshold < bold * fall) {
						hit = max(hit, 1);
					}
				} else if (d >= thick && d < thick + float(trail_px)) {
					float fall = 1.0 - (d - thick) / float(max(trail_px, 1));
					if (threshold < bold * fall * 0.8) {
						hit = max(hit, 2);
					}
				}
			}
		}
		if (hit == 5) {
			COLOR.rgb = fold_color.rgb;
		} else if (hit == 4 || hit == 2) {
			COLOR.rgb = back_color.rgb;
		} else if (hit == 3) {
			COLOR.rgb = shine_color.rgb;
		} else if (hit == 1) {
			COLOR.rgb = glow_color.rgb;
		}
	}
}
