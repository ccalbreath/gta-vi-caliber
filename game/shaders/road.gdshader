shader_type spatial;
// Procedural road ribbon — no textures. CityBuilder.road_ribbon writes UVs
// where UV.x spans the ribbon width 0..1 and UV.y accumulates metres along
// the centreline, so paint and wear stay in road space regardless of where
// the ribbon sits in the world.

uniform vec3 asphalt_color : source_color = vec3(0.24, 0.235, 0.23);
uniform vec3 sidewalk_color : source_color = vec3(0.60, 0.57, 0.51);
uniform vec3 paint_color : source_color = vec3(0.80, 0.75, 0.60);
// Fraction of each ribbon edge that reads as sidewalk-toned concrete.
uniform float sidewalk_frac : hint_range(0.0, 0.4) = 0.14;

varying vec2 v_uv;

float hash21(vec2 p) {
	p = fract(p * vec2(127.13, 311.77));
	p += dot(p, p + 41.23);
	return fract(p.x * p.y);
}

void vertex() {
	v_uv = UV;
}

void fragment() {
	float x = v_uv.x;
	float along = v_uv.y;
	float d_edge = min(x, 1.0 - x);

	// Sidewalk band on both edges, with a darker curb seam against the asphalt.
	float side = 1.0 - smoothstep(sidewalk_frac - 0.012, sidewalk_frac + 0.012, d_edge);
	float curb = 1.0 - smoothstep(0.004, 0.022, abs(d_edge - sidewalk_frac));

	// Faint dashed centre line, repainted long ago: wear varies per dash.
	float line_mask = 1.0 - smoothstep(0.012, 0.022, abs(x - 0.5));
	float dash = step(fract(along / 8.0), 0.55);
	float wear = 0.45 + 0.4 * hash21(vec2(floor(along / 8.0), 7.0));
	float paint = line_mask * dash * wear * (1.0 - side);

	// Patchy asphalt tone so long straights don't read as one flat slab.
	float n = (hash21(floor(vec2(along * 1.5, x * 12.0))) - 0.5) * 0.03;

	vec3 col = asphalt_color + vec3(n);
	col = mix(col, sidewalk_color + vec3(n), side);
	col = mix(col, paint_color, paint * 0.7);
	col *= 1.0 - 0.30 * curb;

	ALBEDO = col;
	ROUGHNESS = 0.92 - 0.25 * paint;
	METALLIC = 0.0;
}
