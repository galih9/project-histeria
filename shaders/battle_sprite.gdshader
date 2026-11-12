shader_type canvas_item;
// Battle sprite effects (GDD 03, Hit feel): white hit flash and a pixel dissolve
// for defeated enemies. Works on real sprites and on placeholder shapes.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge : source_color = vec4(1.0, 0.85, 0.55, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	if (dissolve > 0.0) {
		float n = hash(floor(FRAGCOORD.xy));
		if (n < dissolve) {
			c.a = 0.0;
		} else if (n < dissolve + 0.1) {
			c.rgb = dissolve_edge.rgb;
		}
	}
	COLOR = c;
}
