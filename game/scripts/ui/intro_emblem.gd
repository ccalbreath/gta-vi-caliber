extends Control
## Procedural Art-Deco "outrun" sun emblem for the intro's opening card.
##
## The Vice City sunset motif — a slatted gradient disc (yellow crown fading to
## orange then magenta, cut by widening horizontal slats toward the base) — drawn
## entirely in [method _draw] with zero assets, so it scales crisply at any size
## and needs no texture import. Self-contained brand colours (no [UiPalette] dep)
## so it boots on a clean checkout. Animates a gentle bob and a soft glow pulse.

# Sunset ramp, crown (top) to base (bottom).
const _YELLOW := Color(1.0, 0.88, 0.45)
const _ORANGE := Color(0.992, 0.643, 0.204)
const _MAGENTA := Color(0.913, 0.098, 0.490)

## Horizontal bands the disc is rasterised from (more = smoother edge).
const _BANDS := 44

var _time: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.46
	if r <= 0.0:
		return
	var cx := size.x * 0.5
	# Gentle vertical bob, as if the sun breathes on the horizon.
	var cy := size.y * 0.5 + sin(_time * 1.1) * r * 0.04
	_draw_glow(cx, cy, r)
	_draw_sun(cx, cy, r)


## Soft additive halo so the emblem reads as light, not a flat sticker.
func _draw_glow(cx: float, cy: float, r: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 1.6)
	for i in range(4, 0, -1):
		var f := float(i) / 4.0
		var col := _ORANGE
		col.a = (0.07 + 0.05 * pulse) * (1.0 - f)
		draw_circle(Vector2(cx, cy), r * (1.0 + f * 0.9), col)


## The slatted disc: solid crown, widening gaps toward the base (the retrowave
## sun signature). Each band is a horizontal chord of the circle.
func _draw_sun(cx: float, cy: float, r: float) -> void:
	var band_h := (2.0 * r) / float(_BANDS)
	for i in range(_BANDS):
		var t := float(i) / float(_BANDS - 1)  # 0 crown .. 1 base
		var y := -r + t * 2.0 * r
		var half := sqrt(maxf(r * r - y * y, 0.0))
		if half <= 0.5:
			continue
		# Lower half is cut by slats that widen toward the base.
		if t > 0.5:
			var slat := (t - 0.5) / 0.5
			if fmod(t * 22.0, 1.0) < (0.25 + slat * 0.5):
				continue
		draw_rect(Rect2(cx - half, cy + y - band_h * 0.5, half * 2.0, band_h + 1.0), _sun_color(t))


## Sample the sunset ramp for a band at normalised height [param t] (0 = crown).
func _sun_color(t: float) -> Color:
	if t < 0.5:
		return _YELLOW.lerp(_ORANGE, t * 2.0)
	return _ORANGE.lerp(_MAGENTA, (t - 0.5) * 2.0)
