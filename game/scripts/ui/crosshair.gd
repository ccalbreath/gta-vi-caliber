class_name Crosshair
extends Control
## A four-tick crosshair whose gap widens with the weapon's current spread.
##
## Pure drawing: WeaponHud sets `gap` each frame and calls queue_redraw(). UI
## observes, never drives gameplay (docs/ARCHITECTURE.md).

@export var color: Color = Color(1.0, 1.0, 1.0, 0.92)
@export var tick_length: float = 11.0
@export var thickness: float = 2.5
@export var show_dot: bool = true

@export var kill_color: Color = Color(1.0, 0.25, 0.2)

## Distance (px) from centre to the start of each tick; driven by spread.
var gap: float = 6.0
## Hit-marker: WeaponHud sets to 1.0 on a confirmed hit and fades it; drawn as
## a diagonal X (red on a kill).
var hit_flash: float = 0.0
var hit_kill: bool = false


func _draw() -> void:
	var c := size * 0.5
	# Dark outline underlay first (one px fatter, offset), then the bright ticks,
	# so the reticle stays legible over both bright sky and dark ground.
	_draw_ticks(c, thickness + 2.0, Color(0, 0, 0, 0.55))
	_draw_ticks(c, thickness, color)
	if show_dot:
		draw_circle(c, 2.4, Color(0, 0, 0, 0.55))
		draw_circle(c, 1.5, color)
	if hit_flash > 0.0:
		var marker := kill_color if hit_kill else Color(1, 1, 1)
		marker.a = clampf(hit_flash, 0.0, 1.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw_line(c + dn * 5.0, c + dn * 14.0, Color(0, 0, 0, 0.5), thickness + 2.0)
			draw_line(c + dn * 5.0, c + dn * 14.0, marker, thickness)


func _draw_ticks(c: Vector2, th: float, col: Color) -> void:
	var half := th * 0.5
	# Right, left, down, up ticks.
	draw_rect(Rect2(c + Vector2(gap, -half), Vector2(tick_length, th)), col)
	draw_rect(Rect2(c + Vector2(-gap - tick_length, -half), Vector2(tick_length, th)), col)
	draw_rect(Rect2(c + Vector2(-half, gap), Vector2(th, tick_length)), col)
	draw_rect(Rect2(c + Vector2(-half, -gap - tick_length), Vector2(th, tick_length)), col)
