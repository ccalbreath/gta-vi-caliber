shader_type spatial;
render_mode world_vertex_coords;

// Original state-map ground material: wet tropical grass, dark marsh basins,
// sandy uplands, and fine procedural grain. No texture assets required.

uniform vec3 grass_low : source_color = vec3(0.12, 0.25, 0.12);
uniform vec3 grass_high : source_color = vec3(0.28, 0.42, 0.18);
uniform vec3 marsh_color : source_color = vec3(0.08, 0.16, 0.10);
uniform vec3 dry_sand_color : source_color = vec3(0.58, 0.50, 0.31);
uniform float macro_scale = 0.0022;
uniform float detail_scale = 0.042;
uniform float normal_strength = 0.38;

varying vec3 w_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 845.21));
	p += dot(p, p + 37.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += vnoise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	w_pos = VERTEX;
}

void fragment() {
	vec2 p = w_pos.xz;
	float macro = fbm(p * macro_scale);
	float detail = fbm(p * detail_scale);
	float marsh = smoothstep(0.08, 0.36, fbm((p + vec2(180.0, -90.0)) * 0.004));
	float dry = smoothstep(0.62, 0.86, macro);

	vec3 grass = mix(grass_low, grass_high, detail);
	vec3 col = mix(grass, marsh_color, marsh * 0.55);
	col = mix(col, dry_sand_color, dry * 0.42);
	col *= 0.82 + detail * 0.34;

	// Specular anti-aliasing: the procedural normal grain below is high-frequency,
	// so in the distance it aliases under the pixel grid and the sharp specular
	// lobe makes the ground sparkle/"flash" as the camera and sun move. Fade the
	// normal perturbation flat and push roughness to fully matte with distance so
	// far ground is calm; keep the grain only within ~40 m of the camera.
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float aa = clamp((dist - 40.0) / 140.0, 0.0, 1.0);

	float e = 2.0;
	float h_l = fbm((p - vec2(e, 0.0)) * detail_scale);
	float h_r = fbm((p + vec2(e, 0.0)) * detail_scale);
	float h_d = fbm((p - vec2(0.0, e)) * detail_scale);
	float h_u = fbm((p + vec2(0.0, e)) * detail_scale);
	float ns = normal_strength * (1.0 - aa);
	vec3 n = normalize(vec3((h_l - h_r) * ns, 1.0, (h_d - h_u) * ns));

	ALBEDO = col;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// Matte grass/marsh: high roughness floor + low specular so wet sheen never
	// blows out, trending to 1.0 roughness in the distance.
	float rough = mix(0.96, 0.86, marsh * 0.45);
	ROUGHNESS = mix(rough, 1.0, aa * 0.6);
	SPECULAR = 0.2 * (1.0 - aa * 0.7);
}
