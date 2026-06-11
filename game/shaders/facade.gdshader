shader_type spatial;
render_mode cull_disabled;
// Procedural building facade — no textures. A window grid is carved out of
// mesh-LOCAL position (stable under FloatingOrigin shifts, unlike world space):
// storeys every `floor_height` metres, window bays every `window_step` metres
// along each wall. Per-building wall tone arrives in vertex COLOR (set by
// DistrictLoader from CityBuilder.building_color); per-window variation is
// hashed from the window cell so no two facades read as copy-paste.

// Day->night driver for window emission. A future time-of-day system sets
// this (0 = full daylight, 1 = full night). Default 0 keeps the city sun-lit.
uniform float night_mix : hint_range(0.0, 1.0) = 0.0;
// Storey height, metres (downtown mid/high-rise rhythm).
uniform float floor_height = 3.2;
// Horizontal distance between window bay centres, metres.
uniform float window_step = 2.7;

varying vec3 v_pos; // mesh-local position
varying vec3 v_nrm; // mesh-local normal (flat per wall face)
varying vec3 v_tint; // per-building wall colour from vertex COLOR

float hash21(vec2 p) {
	p = fract(p * vec2(127.13, 311.77));
	p += dot(p, p + 41.23);
	return fract(p.x * p.y);
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
	v_tint = COLOR.rgb;
}

void fragment() {
	// Roof faces point up; walls are vertical.
	float wall = 1.0 - smoothstep(0.55, 0.8, abs(v_nrm.y));

	// Facade-plane coordinates: u runs along the wall, v is height above base.
	vec3 tang = normalize(vec3(-v_nrm.z, 0.0, v_nrm.x) + vec3(1e-4, 0.0, 0.0));
	float u = dot(v_pos, tang);
	float v = v_pos.y;

	vec2 cell = vec2(floor(u / window_step), floor(v / floor_height));
	vec2 f = vec2(fract(u / window_step), fract(v / floor_height));
	// Per-face seed so parallel/opposite facades don't mirror each other.
	float seed = dot(round(v_nrm.xz * 4.0), vec2(17.0, 59.0)) + v_tint.r * 91.0;
	float r = hash21(cell + seed);

	// Punched-window slot inside the cell; some cells stay blank wall.
	float wx = smoothstep(0.30, 0.35, f.x) * (1.0 - smoothstep(0.73, 0.78, f.x));
	float wy = smoothstep(0.28, 0.33, f.y) * (1.0 - smoothstep(0.76, 0.81, f.y));
	float win = wx * wy * wall * step(0.12, r);

	// Worn stucco: low-frequency tone patches, storey ledge lines, street grime.
	float patch = (hash21(floor(vec2(u, v) * 0.45) + seed * 0.7) - 0.5) * 0.14;
	float ledge = 1.0 - 0.16 * (1.0 - smoothstep(0.0, 0.07, f.y)) * wall;
	float grime = 1.0 - 0.28 * (1.0 - smoothstep(0.0, 2.6, v));
	vec3 wall_col = (v_tint + vec3(patch)) * ledge * grime;

	// Roof: darker gravel-toned version of the wall colour.
	float roof_n = (hash21(floor(v_pos.xz * 0.8)) - 0.5) * 0.06;
	vec3 roof_col = v_tint * 0.45 + vec3(roof_n);
	vec3 base_col = mix(roof_col, wall_col, wall);

	// Glass: cool and dark, per-cell brightness so floors don't strobe evenly,
	// with a recess shadow under the lintel so windows read as punched-in.
	float gl = 0.6 + 0.7 * hash21(cell + vec2(seed + 11.0));
	float recess = 1.0 - 0.45 * smoothstep(0.45, 0.78, f.y);
	vec3 glass_col = vec3(0.10, 0.12, 0.15) * gl * recess;

	ALBEDO = mix(base_col, glass_col, win);
	ROUGHNESS = mix(0.78 + 0.18 * hash21(cell - vec2(seed)), 0.14, win);
	METALLIC = 0.0;
	SPECULAR = mix(0.4, 0.6, win);

	// Night life: a hashed subset of rooms lights up, each its own warmth.
	float lit = step(0.62, hash21(cell + vec2(seed + 47.0)));
	vec3 lamp = mix(vec3(1.0, 0.82, 0.55), vec3(0.95, 0.93, 0.85), hash21(cell + vec2(3.0)));
	EMISSION = lamp * win * lit * night_mix * (1.2 + 1.6 * hash21(cell + vec2(seed + 5.0)));
}
