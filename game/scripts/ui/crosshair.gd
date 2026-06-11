class_name Crosshair
extends Control
## A four-tick crosshair whose gap widens with the weapon's current spread.
##
## Pure drawing: WeaponHud sets `gap` each frame and calls queue_redraw(). UI
## observes, never drives gameplay (docs/ARCHITECTURE.md).

@export var color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var tick_length: float = 9.0
@export var thickness: float = 2.0
@export var show_dot: bool = true

## Distance (px) from centre to the start of each tick; driven by spread.
var gap: float = 6.0


func _draw() -> void:
	var c := size * 0.5
	var half := thickness * 0.5
	# Right, left, down, up ticks.
	draw_rect(Rect2(c + Vector2(gap, -half), Vector2(tick_length, thickness)), color)
	draw_rect(Rect2(c + Vector2(-gap - tick_length, -half), Vector2(tick_length, thickness)), color)
	draw_rect(Rect2(c + Vector2(-half, gap), Vector2(thickness, tick_length)), color)
	draw_rect(Rect2(c + Vector2(-half, -gap - tick_length), Vector2(thickness, tick_length)), color)
	if show_dot:
		draw_circle(c, 1.3, color)
