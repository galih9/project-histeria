shader_type canvas_item;
// Roaming hologram look (GDD 01): cyan tint, scanlines, flicker and a rare glitch shift.

uniform vec4 tint : source_color = vec4(0.45, 0.95, 1.0, 1.0);
uniform float flicker_speed = 9.0;
uniform float opacity = 0.85;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	float glitch = step(0.94, hash(floor(TIME * 10.0)));
	VERTEX.x += glitch * (hash(floor(TIME * 10.0) + 1.0) > 0.5 ? 1.0 : -1.0);
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 holo = mix(tint.rgb * 0.45, tint.rgb, clamp(lum + 0.35, 0.0, 1.0));
	float scan = mod(floor(FRAGCOORD.y), 2.0) > 0.5 ? 0.7 : 1.0;
	float flick = 0.85 + 0.15 * sin(TIME * flicker_speed);
	c.rgb = holo * scan * flick;
	c.a *= opacity;
	COLOR = c;
}
