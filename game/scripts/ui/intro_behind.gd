extends Control
## Behind-title cinematic layer (drawn beneath TitleMaster):
##   - a soft god-ray wedge rising from the dusk sun behind the title,
##   - the violet bloom halo around the hero title (three offset, scaled copies),
##   - the diagonal cyan/pink chromatic fringe under the gradient master.
## All values come from IntroSequence's public animation state. Redraws are
## driven by the parent (IntroSequence._apply_to_nodes calls queue_redraw), so
## drawing stops cleanly the moment the timeline reaches its handoff.


func _draw() -> void:
	var seq := get_parent() as IntroSequence
	if seq == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_godray(seq)
	_draw_title_aura(seq)


func _draw_godray(seq: IntroSequence) -> void:
	if seq.godray_alpha <= 0.001:
		return
	var w := size.x
	var h := size.y
	# Sun sits where MenuBackdrop paints it: centre x, ~0.60 height.
	var sun := Vector2(w * 0.5, h * 0.60)
	var spread := w * 0.16
	var top_y := h * 0.18
	var lean := tan(seq.godray_sway) * (sun.y - top_y)
	var points := PackedVector2Array(
		[
			Vector2(sun.x - spread * 0.18, sun.y),
			Vector2(sun.x + spread * 0.18, sun.y),
			Vector2(sun.x + spread + lean, top_y),
			Vector2(sun.x - spread + lean, top_y),
		]
	)
	var warm := IntroSequence.AMBER
	warm.a = seq.godray_alpha
	var cool := IntroSequence.CYAN
	cool.a = 0.0
	draw_polygon(points, PackedColorArray([warm, warm, cool, cool]))


func _draw_title_aura(seq: IntroSequence) -> void:
	if seq.glow_alpha <= 0.001:
		return
	var font := seq.intro_font()
	if font == null:
		return
	var base := seq.title_metrics(size)
	var base_pos: Vector2 = base["pos"]
	var center: Vector2 = base["center"]
	var fsize := IntroSequence.TITLE_FONT_SIZE

	# Violet bloom: three progressively larger, fainter copies recentred so they
	# halo outward from the word. Breathes on the menu's sin(time*1.4) cadence.
	var breath := 0.6 + 0.4 * seq.glow_breath
	var halo_scales := [1.04, 1.09, 1.14]
	var halo_alphas := [0.18, 0.10, 0.05]
	for i in halo_scales.size():
		var hs: float = halo_scales[i]
		var hsize := int(round(fsize * hs))
		var dims := font.get_string_size(
			IntroSequence.TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, hsize
		)
		var pos := Vector2(
			center.x - dims.x * 0.5, center.y - dims.y * 0.5 + font.get_ascent(hsize)
		)
		var col := IntroSequence.VIOLET
		col.a = halo_alphas[i] * seq.glow_alpha * breath
		draw_string(font, pos, IntroSequence.TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, hsize, col)

	# Diagonal anamorphic chromatic fringe: a cyan copy up-left and a pink copy
	# down-right, the split relaxing from 5px to 2px as the title settles.
	var off := seq.chroma_offset
	var cyan := IntroSequence.CYAN
	cyan.a = 0.5 * seq.glow_alpha
	var pink := IntroSequence.PINK
	pink.a = 0.5 * seq.glow_alpha
	draw_string(
		font,
		base_pos + Vector2(-off, -off * 0.5),
		IntroSequence.TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fsize,
		cyan
	)
	draw_string(
		font,
		base_pos + Vector2(off, off * 0.5),
		IntroSequence.TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fsize,
		pink
	)
