class_name WantedStars
extends Control
## Draws the 0–5 wanted-level stars. GameHud sets `stars` (and optionally
## `flash` while heat is actively rising) and calls queue_redraw(). Pure drawing.

@export var total: int = 5
@export var star_radius: float = 9.0
@export var spacing: float = 24.0
@export var lit_color: Color = Color(1.0, 0.85, 0.25)
@export var dim_color: Color = Color(1.0, 1.0, 1.0, 0.12)

var stars: int = 0
var flash: float = 0.0


func _draw() -> void:
	for i in range(total):
		var center := Vector2(star_radius + i * spacing, star_radius + 2.0)
		var lit := i < stars
		var col := lit_color if lit else dim_color
		if lit and flash > 0.0:
			col = col.lerp(Color(1, 1, 1), clampf(flash, 0.0, 1.0))
		# Lit stars get a soft glow halo so the wanted level pulses with menace.
		if lit:
			draw_colored_polygon(
				WantedStars.star_points(center, star_radius + 3.0),
				Color(lit_color.r, lit_color.g, lit_color.b, 0.22)
			)
		# Drop shadow under every star for contrast over bright scenery.
		draw_colored_polygon(
			WantedStars.star_points(center + Vector2(1.5, 1.5), star_radius), Color(0, 0, 0, 0.55)
		)
		draw_colored_polygon(WantedStars.star_points(center, star_radius), col)
		var outline := WantedStars.star_points(center, star_radius)
		draw_polyline(
			outline + PackedVector2Array([outline[0]]),
			Color(0, 0, 0, 0.6) if lit else Color(0, 0, 0, 0.3),
			1.0,
			true
		)


## Five-point star outline (10 alternating outer/inner vertices). Static so the
## geometry can be checked without a tree.
static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var inner := radius * 0.42
	for i in range(10):
		var r := radius if i % 2 == 0 else inner
		var ang := -PI * 0.5 + float(i) * (PI / 5.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts
