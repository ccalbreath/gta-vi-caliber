shader_type canvas_item;
// Analog-film overlay for the boot intro: reads the frame beneath it and adds
// animated grain, fine CRT scanlines and a soft vignette — the textured,
// slightly-degraded look of a VHS title card. A true post-process (samples the
// screen texture) so it modulates the real pixels rather than washing a flat
// translucent layer over them. Kept subtle so it reads as texture, not noise.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.07;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.045;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// Animated film grain — per-pixel, varied each frame via TIME.
	float g = hash(FRAGCOORD.xy + fract(TIME) * 91.7);
	col += (g - 0.5) * grain_strength;

	// Fine CRT scanlines (every ~2 px), darkening alternate lines.
	float sl = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	col *= 1.0 - scanline_strength * sl;

	// Soft vignette toward the frame edges.
	float vig = smoothstep(0.85, 0.25, length(UV - 0.5));
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
