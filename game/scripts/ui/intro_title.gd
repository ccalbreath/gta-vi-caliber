extends Control
## Hero-title layer: stamps "NEON BAY" centred, once, carrying the
## title_neon.gdshader material that fills the glyphs with the pink->amber melt.
## Fade-up and the ignite scale-punch are animated on this node by IntroSequence
## (via modulate/scale), so the word itself only needs to be drawn when the
## layout changes — the gradient is in the shader, not here.


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var seq := get_parent() as IntroSequence
	if seq == null:
		return
	var font := seq.intro_font()
	if font == null or size.x <= 0.0:
		return
	var m := seq.title_metrics(size)
	var fsize := IntroSequence.TITLE_FONT_SIZE
	# Feed the shader the word's local pixel band (cap top -> baseline) so the
	# pink->amber melt spans the glyphs rather than the whole node rect.
	var pos: Vector2 = m["pos"]
	var ascent := font.get_ascent(fsize)
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("title_top", pos.y - ascent)
		mat.set_shader_parameter("title_height", ascent)
	draw_string(font, pos, IntroSequence.TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
