// Subtle world-space grid for the floor: minor lines every 1 m, major every 5 m,
// fading out with distance to avoid aliasing at the horizon.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.13, 0.14, 0.17);
uniform vec3 line_color : source_color = vec3(0.32, 0.36, 0.44);
uniform vec3 major_color : source_color = vec3(0.45, 0.52, 0.65);

varying vec3 world_pos;

float grid(vec2 p, float spacing, float width) {
	vec2 c = p / spacing;
	vec2 g = abs(fract(c - 0.5) - 0.5) / fwidth(c);
	return 1.0 - min(min(g.x, g.y) / width, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fade = 1.0 - smoothstep(20.0, 45.0, length(world_pos.xz));
	vec3 col = mix(base_color, line_color, grid(world_pos.xz, 1.0, 1.0) * 0.6 * fade);
	col = mix(col, major_color, grid(world_pos.xz, 5.0, 1.5) * 0.8 * fade);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
