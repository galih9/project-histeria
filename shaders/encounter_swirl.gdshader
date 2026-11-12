shader_type canvas_item;
// EarthBound-style encounter swirl (GDD 01, "Encounter transition").
// The tint tells who has the advantage: green = party first strike,
// red = enemy first strike, purple = neutral.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.4, 0.95, 1.0);
uniform vec2 resolution = vec2(256.0, 224.0);

void fragment() {
	vec2 px = floor(UV * resolution) / resolution;
	vec2 c = (px - 0.5) * vec2(resolution.x / resolution.y, 1.0);
	float r = length(c);
	float angle = atan(c.y, c.x) / 6.2831853 + 0.5;
	float arms = fract((angle + r * 1.8 - progress * 1.5) * 3.0);

	float reach = progress * 1.9 - r;
	float covered = step(1.0 - arms, reach * 2.2) + step(0.98, progress);
	covered = clamp(covered, 0.0, 1.0);

	float stripe = step(0.5, fract(r * 7.0 - progress * 4.0));
	vec3 col = mix(tint.rgb, tint.rgb * 0.25, stripe);
	col = mix(col, vec3(0.0), smoothstep(0.75, 1.0, progress));
	COLOR = vec4(col, covered);
}
