shader_type canvas_item;
render_mode blend_mix;
// The project's first canvas_item shader. Fills text glyphs — drawn with
// draw_string() on the node carrying this material — with the signature
// sunset-neon melt: hot pink at the top of the word fading to amber at the
// baseline. The gradient is driven by each glyph quad's LOCAL vertex Y carried
// through a varying (the font-atlas UV cannot express a word-wide gradient: it
// maps into the atlas, not the glyph height). VERTEX is pre-transform, so the
// melt is invariant to the node's ignite scale-punch and never slides off the
// letters. `title_top`/`title_height` are the word's local pixel band, set by
// the title layer each draw. Coverage comes from the font alpha, so only the
// glyphs are tinted and the node rect never shows. Glow/bloom and the
// light-sweep live in the sibling _draw layers, not here.

varying float v_local_y;

uniform vec3 top_color : source_color = vec3(1.0, 0.18, 0.62); // hot pink
uniform vec3 bottom_color : source_color = vec3(1.0, 0.6, 0.1); // amber
uniform float title_top = 0.0; // local Y of the word's top, in pixels
uniform float title_height = 1.0; // local pixel height of the gradient band
uniform float boost : hint_range(1.0, 2.0) = 1.06; // gentle lift so neon reads hot

void vertex() {
	v_local_y = VERTEX.y;
}

void fragment() {
	float coverage = texture(TEXTURE, UV).a;
	float g = clamp((v_local_y - title_top) / max(title_height, 1.0), 0.0, 1.0);
	vec3 grad = mix(top_color, bottom_color, g);
	// Multiply by the incoming alpha so the node's modulate fades the whole word.
	COLOR = vec4(grad * boost, coverage * COLOR.a);
}
