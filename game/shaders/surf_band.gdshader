shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_disabled;

uniform vec4 u_foam_color : source_color = vec4(0.95, 0.97, 0.94, 0.82);
uniform float u_time = 0.0;
uniform float u_band_index = 0.0;
uniform float u_opacity : hint_range(0.0, 1.0) = 0.7;


void fragment() {
	float cross = 1.0 - abs(UV.x * 2.0 - 1.0);
	float body = smoothstep(0.08, 0.7, cross);
	float run = sin(UV.y * 0.10 - u_time * (1.3 + u_band_index * 0.18));
	float chop = sin(UV.y * 0.34 + u_time * 1.9 + UV.x * 12.0 + u_band_index);
	float foam = smoothstep(0.12, 0.72, run * 0.45 + chop * 0.35 + cross * 0.55);
	float alpha = foam * body * u_opacity;
	ALBEDO = u_foam_color.rgb;
	EMISSION = u_foam_color.rgb * (0.35 + foam * 0.65);
	ROUGHNESS = 0.92;
	ALPHA = alpha;
}
