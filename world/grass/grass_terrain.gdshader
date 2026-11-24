shader_type canvas_item;
// Valdrin-style sub-tile mask + noise-eaten edge terrain shader.
//
// Reads a coarse RGBA8 sub-tile mask (default 2x2 px per sub-cell = 64 cells
// per 16x16 tile) sampled with bilinear filtering to obtain smooth coverage
// gradients, then erodes grass/dirt boundaries with multi-scale pixel-snapped
// noise so crisp grass blades and tufts poke organically over dirt & paths.

uniform sampler2D mask_texture : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(0.0);
uniform vec2 map_size = vec2(640.0, 480.0);

group_uniforms GrassPalette;
uniform vec4 grass_deep : source_color = vec4(0.184, 0.329, 0.149, 1.0);   // #2f5426
uniform vec4 grass_dark : source_color = vec4(0.243, 0.412, 0.173, 1.0);   // #3e692c
uniform vec4 grass_mid : source_color = vec4(0.310, 0.498, 0.200, 1.0);    // #4f7f33
uniform vec4 grass_light : source_color = vec4(0.392, 0.588, 0.235, 1.0);  // #64963c
uniform vec4 grass_tip : source_color = vec4(0.494, 0.686, 0.290, 1.0);    // #7eaf4a

group_uniforms DirtPalette;
uniform vec4 path_dark : source_color = vec4(0.588, 0.478, 0.322, 1.0);    // #967a52
uniform vec4 path_mid : source_color = vec4(0.698, 0.580, 0.408, 1.0);     // #b29468
uniform vec4 path_light : source_color = vec4(0.788, 0.678, 0.494, 1.0);   // #c9ad7e
uniform vec4 worn_dark : source_color = vec4(0.298, 0.220, 0.141, 1.0);    // #4c3824
uniform vec4 worn_mid : source_color = vec4(0.388, 0.290, 0.188, 1.0);     // #634a30
uniform vec4 worn_light : source_color = vec4(0.478, 0.365, 0.243, 1.0);   // #7a5d3e

group_uniforms Flowers;
uniform vec4 flower_white : source_color = vec4(0.902, 0.929, 0.878, 1.0); // #e6ede0
uniform vec4 flower_yellow : source_color = vec4(0.949, 0.824, 0.322, 1.0);// #f2d252
uniform float flower_density : hint_range(0.0, 1.0) = 0.22;

group_uniforms Shape;
uniform float edge_erosion : hint_range(0.0, 1.2) = 0.86;
uniform float patch_scale : hint_range(16.0, 160.0) = 56.0;
uniform float tuft_density : hint_range(0.0, 1.0) = 0.78;
uniform float ao_strength : hint_range(0.0, 0.6) = 0.22;
uniform float seed_offset = 0.0;

varying vec2 v_pos;

// Dave Hoskins hash functions (sin-free for consistent GL compatibility precision).
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		total += value_noise(p) * amp;
		p = p * 2.07 + vec2(19.3, 11.7);
		amp *= 0.5;
	}
	return total / 0.875;
}

float edge_noise_at(vec2 px, vec2 seed_v) {
	float coarse = fbm(px / 18.0 + seed_v);
	float clump = value_noise(px / 5.5 + seed_v * 1.7);
	float blade = mix(hash21(vec2(px.x, floor(px.y * 0.5)) + seed_v), hash21(px + seed_v), 0.45);
	return coarse * 0.46 + clump * 0.34 + blade * 0.20;
}

float eval_eroded(vec2 px, vec2 seed_v, out vec4 mask_sample, out float edge_n) {
	vec2 safe_size = max(map_size, vec2(1.0));
	vec2 uv = clamp((px + 0.5) / safe_size, vec2(0.001), vec2(0.999));
	mask_sample = texture(mask_texture, uv);
	edge_n = edge_noise_at(px, seed_v);
	return mask_sample.r + (edge_n - 0.5) * edge_erosion;
}

void vertex() {
	v_pos = VERTEX - map_origin;
}

void fragment() {
	vec2 px = floor(v_pos + 0.001);
	vec2 seed_v = vec2(seed_offset, seed_offset * 0.63);

	vec4 m;
	float edge_n;
	float eroded = eval_eroded(px, seed_v, m, edge_n);
	float worn = m.g;
	float lush = m.b;
	float ao = m.a;

	vec3 col;

	if (eroded >= 0.5) {
		// --- Grass field ----------------------------------------------------
		// Broad painterly meadow patches (domain-warped FBM).
		vec2 p_uv = px / patch_scale + seed_v;
		vec2 warp = vec2(value_noise(p_uv * 0.8 + vec2(4.2, 1.7)), value_noise(p_uv * 0.8 + vec2(9.1, 6.4)));
		float patch_n = fbm(p_uv + (warp - 0.5) * 0.85);
		float clump_n = value_noise(px / 11.0 + seed_v * 2.1);

		float tone = clamp(patch_n * 0.68 + clump_n * 0.24 + (lush - 0.5) * 0.22, 0.0, 1.0);
		if (tone < 0.34) {
			col = grass_deep.rgb;
		} else if (tone < 0.58) {
			col = grass_dark.rgb;
		} else if (tone < 0.80) {
			col = grass_mid.rgb;
		} else {
			col = grass_light.rgb;
		}

		// Subtle root undertone along noise-eaten grass border.
		if (eroded < 0.60) {
			float border_h = hash21(px + seed_v * 3.1);
			if (border_h < 0.45) {
				col = grass_dark.rgb;
			} else if (border_h > 0.86) {
				col = grass_light.rgb;
			}
		}

		// Relative shades one step darker/lighter than local meadow patch so tufts blend naturally.
		vec3 shade_darker = (tone < 0.34) ? grass_deep.rgb * 0.88 : ((tone < 0.58) ? grass_deep.rgb : ((tone < 0.80) ? grass_dark.rgb : grass_mid.rgb));
		vec3 shade_brighter = (tone < 0.34) ? grass_dark.rgb : ((tone < 0.58) ? grass_mid.rgb : ((tone < 0.80) ? grass_light.rgb : grass_tip.rgb));

		// Layer 1 (7x9 staggered grid): crisp asymmetric 1-2px blade ticks & subtle tufts.
		vec2 cell_a = vec2(7.0, 9.0);
		vec2 px_a = px + vec2(floor(px.y / cell_a.y) * 3.0, 0.0);
		vec2 cid_a = floor(px_a / cell_a);
		vec2 loc_a = px_a - cid_a * cell_a;
		float roll_a = hash21(cid_a + vec2(71.3, 19.7) + seed_v);
		if (roll_a < tuft_density * mix(0.28, 0.58, lush)) {
			vec2 org_a = floor(vec2(1.0, 2.0) + hash22(cid_a + seed_v * 1.9) * vec2(4.0, 5.0));
			vec2 d = loc_a - org_a;
			float kind = hash21(cid_a + vec2(37.1, 83.4) + seed_v);
			if (kind < 0.52) {
				// 1x2 crisp vertical grass blade tick.
				if (d == vec2(0.0, 0.0)) {
					col = shade_brighter;
				} else if (d == vec2(0.0, 1.0)) {
					col = shade_darker;
				}
			} else {
				// Stepped 2-blade asymmetric tuft (no wide triangles).
				if (d == vec2(0.0, 0.0) || d == vec2(1.0, -1.0)) {
					col = shade_brighter;
				} else if (d == vec2(0.0, 1.0) || d == vec2(1.0, 0.0)) {
					col = shade_darker;
				}
			}
		}

		// Layer 2 (10x7 staggered grid): small dark root & crevice accents for Valdrin micro-depth.
		vec2 cell_b = vec2(10.0, 7.0);
		vec2 px_b = px + vec2(4.0, floor(px.x / cell_b.x) * 2.0);
		vec2 cid_b = floor(px_b / cell_b);
		vec2 loc_b = px_b - cid_b * cell_b;
		if (hash21(cid_b + vec2(19.1, 67.3) + seed_v) < tuft_density * 0.45) {
			vec2 org_b = floor(vec2(1.0, 1.0) + hash22(cid_b + vec2(4.3, 8.1) + seed_v) * vec2(7.0, 4.0));
			vec2 d = loc_b - org_b;
			float kind_b = hash21(cid_b + vec2(53.7, 11.2));
			if (d == vec2(0.0, 0.0) || (kind_b > 0.45 && d == vec2(1.0, 0.0)) || (kind_b > 0.78 && d == vec2(0.0, 1.0))) {
				col = shade_darker;
			}
		}

		// Layer 3 (11x11 sparse sunlit blade flecks on brighter turf).
		vec2 px_c = px + vec2(5.0, 3.0);
		vec2 cid_c = floor(px_c / 11.0);
		vec2 loc_c = px_c - cid_c * 11.0;
		if (tone > 0.40 && hash21(cid_c + vec2(13.7, 52.9) + seed_v) < tuft_density * 0.40 * lush) {
			vec2 org_c = floor(vec2(1.0) + hash22(cid_c + vec2(5.1, 9.8) + seed_v) * 8.0);
			vec2 d2 = loc_c - org_c;
			if (d2 == vec2(0.0, 0.0)) {
				col = grass_tip.rgb;
			} else if (d2 == vec2(0.0, 1.0)) {
				col = grass_light.rgb;
			}
		}

		// Sparse tiny wildflowers away from dirt edges and trimmed paths.
		if (m.r > 0.85 && lush > 0.45 && flower_density > 0.01) {
			vec2 f_cid = floor(px / 16.0);
			vec2 f_local = px - f_cid * 16.0;
			float f_roll = hash21(f_cid + vec2(101.3, 47.9) + seed_v);
			if (f_roll < flower_density * 0.45) {
				vec2 f_org = floor(vec2(2.0) + hash22(f_cid + vec2(17.2, 63.1)) * 11.0);
				vec2 fd = f_local - f_org;
				float f_type = hash21(f_cid + vec2(8.4, 91.2));
				if (f_type < 0.65) {
					// Tiny 1x2 white-ish wildflower fleck.
					if (fd == vec2(0.0, 0.0)) {
						col = flower_white.rgb;
					} else if (fd == vec2(0.0, 1.0)) {
						col = grass_light.rgb;
					}
				} else {
					// Tiny 2-3px yellow blossom cluster.
					if (fd == vec2(0.0, 0.0) || fd == vec2(1.0, 0.0) || (fd == vec2(0.0, -1.0) && f_type > 0.82)) {
						col = flower_yellow.rgb;
					}
				}
			}
		}
	} else {
		// --- Bare dirt / sandy path -----------------------------------------
		float soil_macro = value_noise(px / 12.0 + seed_v * 1.3);
		float soil_grain = hash21(px + vec2(29.0, 41.0) + seed_v);
		float soil_val = soil_macro * 0.65 + soil_grain * 0.35;

		// Noise-eaten blend between warm sandy paths and dark worn earth under props/scars.
		bool is_worn = (worn + (edge_n - 0.5) * 0.55) >= 0.45;
		if (is_worn) {
			if (soil_val < 0.35) {
				col = worn_dark.rgb;
			} else if (soil_val < 0.72) {
				col = worn_mid.rgb;
			} else {
				col = worn_light.rgb;
			}
		} else {
			if (soil_val < 0.30) {
				col = path_dark.rgb;
			} else if (soil_val < 0.74) {
				col = path_mid.rgb;
			} else {
				col = path_light.rgb;
			}
		}

		// Subtle 1px root shadow immediately south of overhanging grass edges.
		vec4 mn;
		float en_n;
		float eroded_north = eval_eroded(px - vec2(0.0, 1.0), seed_v, mn, en_n);
		if (eroded_north >= 0.5) {
			col *= 0.84;
		}
	}

	// Subtle ambient occlusion under trees, buildings, and rocks.
	float ao_factor = mix(1.0, 1.0 - ao_strength, clamp(1.0 - ao, 0.0, 1.0));
	COLOR = vec4(col * ao_factor, 1.0);
}
