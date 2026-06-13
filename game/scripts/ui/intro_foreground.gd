extends Control
## Foreground cinematic layer (drawn above the title): the opening studio-sting
## emblem, the implied 2.39:1 cinematic frame (soft letterbox + edge vignette),
## the single light-sweep raking the hero title, and the settle copy (subtitle +
## pulsing PRESS ANY KEY). All timing comes from IntroSequence's public state.
## Redraws are driven by the parent (IntroSequence._apply_to_nodes), so drawing
## stops cleanly at the handoff rather than running occluded behind the fade.

# Studio-emblem geometry is static (it depends only on the control size), so it
# is baked once and rebuilt only on resize instead of every frame.
var _emblem_center := Vector2.ZERO
var _emblem_radius := 104.0
var _ring := PackedVector2Array()
var _inner := PackedVector2Array()
var _wave := PackedVector2Array()
var _geo_size := Vector2.ZERO


func _draw() -> void:
	var seq := get_parent() as IntroSequence
	if seq == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if seq.emblem_alpha > 0.001:
		_draw_studio(seq)
	if seq.letterbox_amount > 0.001:
		_draw_frame(seq)
	if seq.sweep_strength > 0.001:
		_draw_sweep(seq)
	if seq.subtitle_alpha > 0.001:
		_draw_subtitle(seq)
	if seq.prompt_alpha > 0.001:
		_draw_prompt(seq)


# --- Studio sting ------------------------------------------------------------
func _ensure_geometry() -> void:
	if _geo_size == size and not _ring.is_empty():
		return
	_geo_size = size
	_emblem_center = Vector2(size.x * 0.5, size.y * 0.46)
	_emblem_radius = 104.0
	_ring = _hexagon(_emblem_center, _emblem_radius, 12)
	_inner = _hexagon(_emblem_center, _emblem_radius - 7.0, 12)
	_wave = _wave_points(_emblem_center, _emblem_radius)


func _draw_studio(seq: IntroSequence) -> void:
	_ensure_geometry()
	var center := _emblem_center
	var radius := _emblem_radius
	var a := seq.emblem_alpha
	var progress := seq.emblem_progress

	# Soft self-lit cyan bloom behind the mark.
	for i in 3:
		var f := float(i)
		var col := IntroSequence.CYAN
		col.a = (0.12 - f * 0.035) * a
		draw_circle(center, radius * (0.9 + f * 0.55), col)

	# Outer hex ring writes itself on, with a converging cyan/pink chroma split.
	var split := Vector2(seq.emblem_split, 0.0)
	if seq.emblem_split > 0.1:
		_polyline_progress(_ring, progress, _with_alpha(IntroSequence.PINK, 0.5 * a), 4.0, split)
		_polyline_progress(_ring, progress, _with_alpha(IntroSequence.CYAN, 0.5 * a), 4.0, -split)
	_polyline_progress(_ring, progress, _with_alpha(IntroSequence.CYAN, a), 5.0, Vector2.ZERO)

	# Inner pink accent ring, slightly inset.
	_polyline_progress(
		_inner, progress, _with_alpha(IntroSequence.PINK, 0.85 * a), 3.0, Vector2.ZERO
	)

	# A 'bay wave' chevron through the lower third.
	var wave_p := clampf((progress - 0.35) / 0.65, 0.0, 1.0)
	_polyline_progress(_wave, wave_p, _with_alpha(IntroSequence.CYAN, a), 3.0, Vector2.ZERO)

	# Amber sun-dot lands once the mark is nearly drawn.
	if progress > 0.55:
		var dot := clampf((progress - 0.55) / 0.45, 0.0, 1.0)
		draw_circle(
			center - Vector2(0, radius * 0.18), 9.0 * dot, _with_alpha(IntroSequence.AMBER, a)
		)

	# Wordmark, airy tracking, warm white, below the badge.
	var font := seq.intro_font()
	if font != null:
		var base := center.y + radius + 54.0
		_draw_tracked(
			font,
			IntroSequence.STUDIO_TEXT,
			center.x,
			base,
			IntroSequence.STUDIO_FONT_SIZE,
			6.0,
			_with_alpha(IntroSequence.WARM_WHITE, seq.emblem_word_alpha)
		)


# --- Implied cinematic frame -------------------------------------------------
func _draw_frame(seq: IntroSequence) -> void:
	var w := size.x
	var h := size.y
	var lb := seq.letterbox_amount
	var bar := h * 0.10 * lb
	var top_a := 0.5 * lb
	# Soft top/bottom letterbox: dark at the edge, fading to clear at the inner lip.
	var black := Color(0, 0, 0, 1)
	_grad_quad(Vector2(0, 0), Vector2(w, 0), Vector2(w, bar), Vector2(0, bar), top_a, 0.0, black)
	_grad_quad(
		Vector2(0, h - bar), Vector2(w, h - bar), Vector2(w, h), Vector2(0, h), 0.0, top_a, black
	)
	# Faint left/right vignette so the frame reads cinematic, not banded.
	var side := w * 0.16
	var side_a := 0.20 * seq.vignette_amount
	_grad_quad(Vector2(0, 0), Vector2(side, 0), Vector2(side, h), Vector2(0, h), side_a, 0.0, black)
	_grad_quad(
		Vector2(w - side, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - side, h), 0.0, side_a, black
	)


# --- Light-sweep rake across the title --------------------------------------
func _draw_sweep(seq: IntroSequence) -> void:
	var font := seq.intro_font()
	if font == null:
		return
	var m := seq.title_metrics(size)
	var pos: Vector2 = m["pos"]
	var dims: Vector2 = m["dims"]
	var fsize := IntroSequence.TITLE_FONT_SIZE
	var sweep_x := pos.x + seq.sweep_pos * dims.x
	var band := dims.x * 0.16
	var cursor := pos.x
	for c in IntroSequence.TITLE_TEXT:
		var cw := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var d := (cursor + cw * 0.5 - sweep_x) / band
		var b := exp(-d * d)
		var alpha := b * seq.sweep_strength
		if alpha > 0.01:
			draw_char(
				font, Vector2(cursor, pos.y), c, fsize, _with_alpha(IntroSequence.SWEEP_CORE, alpha)
			)
		cursor += cw


# --- Settle copy -------------------------------------------------------------
func _draw_subtitle(seq: IntroSequence) -> void:
	var font := seq.intro_font()
	if font == null:
		return
	var m := seq.title_metrics(size)
	var center: Vector2 = m["center"]
	var dims: Vector2 = m["dims"]
	var fsize := IntroSequence.SUBTITLE_FONT_SIZE
	var sd := font.get_string_size(
		IntroSequence.SUBTITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize
	)
	var baseline := center.y + dims.y * 0.5 + 44.0
	draw_string(
		font,
		Vector2(center.x - sd.x * 0.5, baseline),
		IntroSequence.SUBTITLE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fsize,
		Color(1, 1, 1, seq.subtitle_alpha)
	)


func _draw_prompt(seq: IntroSequence) -> void:
	var font := seq.intro_font()
	if font == null:
		return
	var baseline := size.y * 0.86
	var col := _with_alpha(IntroSequence.AMBER, seq.prompt_alpha * seq.prompt_pulse)
	_draw_tracked(
		font,
		IntroSequence.PROMPT_TEXT,
		size.x * 0.5,
		baseline,
		IntroSequence.PROMPT_FONT_SIZE,
		5.0,
		col
	)


# --- Draw helpers ------------------------------------------------------------
func _with_alpha(base: Color, a: float) -> Color:
	return Color(base.r, base.g, base.b, clampf(a, 0.0, 1.0))


func _hexagon(center: Vector2, radius: float, per_edge: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in 6:
		var a0 := deg_to_rad(60.0 * float(v) - 90.0)
		var a1 := deg_to_rad(60.0 * float(v + 1) - 90.0)
		var p0 := center + Vector2(cos(a0), sin(a0)) * radius
		var p1 := center + Vector2(cos(a1), sin(a1)) * radius
		for s in per_edge:
			pts.append(p0.lerp(p1, float(s) / float(per_edge)))
	var first := deg_to_rad(-90.0)
	pts.append(center + Vector2(cos(first), sin(first)) * radius)
	return pts


func _wave_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var span := radius * 1.3
	var y0 := center.y + radius * 0.34
	var steps := 40
	for s in steps + 1:
		var f := float(s) / float(steps)
		pts.append(Vector2(center.x - span * 0.5 + span * f, y0 + sin(f * TAU) * radius * 0.12))
	return pts


func _polyline_progress(
	pts: PackedVector2Array, progress: float, col: Color, width: float, offset: Vector2
) -> void:
	var n := int(ceil(clampf(progress, 0.0, 1.0) * float(pts.size())))
	if n < 2:
		return
	var slice := pts.slice(0, n)
	if offset != Vector2.ZERO:
		for i in slice.size():
			slice[i] += offset
	draw_polyline(slice, col, width, true)


## Draws a quad with a per-vertex alpha gradient (a0 on the v0/v1 edge, a1 on the
## v2/v3 edge) — used for the soft letterbox/vignette bands.
func _grad_quad(
	v0: Vector2, v1: Vector2, v2: Vector2, v3: Vector2, a0: float, a1: float, base: Color
) -> void:
	var c0 := Color(base.r, base.g, base.b, a0)
	var c1 := Color(base.r, base.g, base.b, a1)
	draw_polygon(PackedVector2Array([v0, v1, v2, v3]), PackedColorArray([c0, c0, c1, c1]))


func _draw_tracked(
	font: Font,
	text: String,
	center_x: float,
	baseline_y: float,
	fsize: int,
	tracking: float,
	col: Color
) -> void:
	var widths := PackedFloat32Array()
	var total := 0.0
	for c in text:
		var cw := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		widths.append(cw)
		total += cw + tracking
	total -= tracking
	var x := center_x - total * 0.5
	var i := 0
	for c in text:
		draw_char(font, Vector2(x, baseline_y), c, fsize, col)
		x += widths[i] + tracking
		i += 1
