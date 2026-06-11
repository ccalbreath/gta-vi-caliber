class_name Minimap
extends Control
## A GTA-style circular minimap (roadmap M5): a dark disc that follows the
## player, with coloured blips for points-of-interest and citizens, the player as
## an arrow at the centre, and a north tick. All the coordinate math is in
## MapProjection (pure, tested); this node just gathers nodes by group and draws.
##
## Rotates so the player's heading points up. POI blips outside the disc clamp to
## the rim so distant places still read as a direction; citizen blips only show
## when actually nearby.

## Blip colour per POI kind; anything unlisted uses a neutral grey.
const POI_COLORS: Dictionary = {
	"office": Color(0.45, 0.6, 0.95),
	"diner": Color(0.95, 0.5, 0.4),
	"bar": Color(0.7, 0.5, 0.9),
	"gym": Color(0.4, 0.85, 0.7),
	"home": Color(0.9, 0.8, 0.45),
	"park": Color(0.45, 0.85, 0.45),
}

## Radius of the minimap disc in pixels.
@export var radius: float = 96.0
## World metres per pixel — higher zooms out.
@export var meters_per_pixel: float = 1.6
## Spin the map so the player faces up (vs. fixed north-up).
@export var rotate_with_player: bool = true
@export var bg_color: Color = Color(0.08, 0.09, 0.12, 0.72)
@export var citizen_color: Color = Color(0.55, 0.8, 1.0)
@export var player_color: Color = Color(1, 1, 1)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, bg_color)

	var player := _player()
	if player != null:
		var origin := player.global_position
		var rot := -player.rotation.y if rotate_with_player else 0.0
		_draw_pois(center, origin, rot)
		_draw_citizens(center, origin, rot)

	# Disc outline + a north tick at the top.
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)
	draw_line(
		center + Vector2(0, -radius), center + Vector2(0, -radius + 8.0), Color(1, 1, 1, 0.7), 2.0
	)
	_draw_player_marker(center)


func _draw_pois(center: Vector2, origin: Vector3, rot: float) -> void:
	for place in POI_COLORS:
		var color: Color = POI_COLORS[place]
		for node in get_tree().get_nodes_in_group("poi_%s" % place):
			var n := node as Node3D
			if n == null:
				continue
			var mp := MapProjection.world_to_map(n.global_position, origin, meters_per_pixel, rot)
			mp = MapProjection.clamp_to_ring(mp, radius)
			draw_circle(center + mp, 4.0, color)


func _draw_citizens(center: Vector2, origin: Vector3, rot: float) -> void:
	for node in get_tree().get_nodes_in_group("citizens"):
		var n := node as Node3D
		if n == null:
			continue
		var mp := MapProjection.world_to_map(n.global_position, origin, meters_per_pixel, rot)
		if MapProjection.is_within(mp, radius):
			draw_circle(center + mp, 2.0, citizen_color)


func _draw_player_marker(center: Vector2) -> void:
	# A small triangle pointing up (the map already rotates under it).
	var pts := PackedVector2Array(
		[center + Vector2(0, -6), center + Vector2(-4, 5), center + Vector2(4, 5)]
	)
	draw_colored_polygon(pts, player_color)


func _player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node3D if not players.is_empty() else null
