class_name FullMap
extends Control
## The full-screen map (roadmap M5, the other half of "minimap + full map UI"):
## press M to toss up a north-up overview of the whole district — every labelled
## POI, the player's position and heading, auto-zoomed to fit. Reuses the same
## tested MapProjection as the minimap, and the minimap's POI colours, so the two
## never disagree about where things are.

## Padding (px) between the mapped area and the screen edge.
@export var margin: float = 64.0
## Key that toggles the map.
@export var toggle_key: Key = KEY_M

var _font: Font = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == toggle_key:
		visible = not visible
		queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09, 0.93))

	var pois := _gather_pois()
	var player := _player()
	var pts: Array = pois.duplicate()
	if player != null:
		pts.append({"pos": player.global_position})
	if pts.is_empty():
		return

	var bounds := _bounds(pts)
	var center: Vector3 = bounds["center"]
	var mpp := MapProjection.fit_meters_per_pixel(bounds["extent"], size, margin)
	var view_center := size * 0.5

	for poi in pois:
		var mp := MapProjection.world_to_map(poi["pos"], center, mpp)
		var at := view_center + mp
		draw_circle(at, 7.0, poi["color"])
		draw_string(
			_font,
			at + Vector2(10, 5),
			String(poi["label"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16
		)

	if player != null:
		var pp := view_center + MapProjection.world_to_map(player.global_position, center, mpp)
		draw_circle(pp, 6.0, Color(1, 1, 1))
		draw_circle(pp, 6.0, Color(0.1, 0.5, 1.0))

	draw_string(
		_font,
		Vector2(margin, margin * 0.6),
		"MAP  —  press M to close",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22
	)


func _gather_pois() -> Array:
	var out: Array = []
	for place in Minimap.POI_COLORS:
		for node in get_tree().get_nodes_in_group("poi_%s" % place):
			var n := node as Node3D
			if n != null:
				out.append(
					{"pos": n.global_position, "color": Minimap.POI_COLORS[place], "label": place}
				)
	return out


## Axis-aligned XZ bounds of a set of {pos} points -> {center, extent}.
func _bounds(pts: Array) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in pts:
		var pos: Vector3 = p["pos"]
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		min_z = minf(min_z, pos.z)
		max_z = maxf(max_z, pos.z)
	var center := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
	var extent := Vector2(maxf(max_x - min_x, 1.0), maxf(max_z - min_z, 1.0))
	return {"center": center, "extent": extent}


func _player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as Node3D if not players.is_empty() else null
