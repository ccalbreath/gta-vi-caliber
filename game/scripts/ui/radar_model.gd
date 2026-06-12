class_name RadarModel
extends RefCounted
## Pure GTA-style radar/minimap blip math — the projection side of the HUD radar.
## Turns world positions into points on a 2D radar disc that rotates with the
## player so their facing always points "up", scales world metres to radar pixels,
## edge-clamps out-of-range blips to the rim as direction arrows, and assigns
## stable faction colours. This is what a minimap Control iterates over to draw.
##
## All static, all pure math, no nodes — unit-tests headless
## (tests/unit/test_radar_model.gd). Work happens in the XZ world plane (y is up).
##
## Conventions, fixed and tested:
##   * Yaw is rotation about Godot's +Y axis. At yaw = 0 the player faces -Z
##     (Godot's default forward). Forward in XZ is therefore (sin yaw, -cos yaw);
##     the player's right in XZ is (cos yaw, sin yaw).
##   * Radar space is MATH-style, not screen-space: x = right, y = UP, where +Y
##     is the direction the player faces. An entity dead ahead at half range sits
##     near (0, +radar_radius_px / 2). A drawing node that wants screen pixels
##     simply negates y (screen +Y is down).
##   * `bearing_to` is signed: 0 = dead ahead, positive = the entity is to the
##     player's RIGHT, negative = to the LEFT (consistent with radar +X = right).


## Flatten a world vector onto the XZ ground plane as a Vector2 (x, z).
static func _flatten(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Player forward direction in XZ for a given yaw (about +Y). Unit length.
## yaw = 0 → (0, -1) = -Z (Godot default forward).
static func _forward_xz(yaw: float) -> Vector2:
	return Vector2(sin(yaw), -cos(yaw))


## Player right direction in XZ for a given yaw. Unit length.
## yaw = 0 → (1, 0) = +X (east is on the player's right when facing -Z/north).
static func _right_xz(yaw: float) -> Vector2:
	return Vector2(cos(yaw), sin(yaw))


## Project an entity onto the radar disc. Returns radar-space pixels with x =
## right, y = up (player facing maps to +Y). The world offset (entity - player)
## is flattened to XZ, rotated so the player's facing becomes +Y, then scaled by
## (radar_radius_px / range_m). An entity directly in front at half range lands
## at roughly (0, +radar_radius_px / 2). Degenerate range → (0, 0), no NaN.
static func to_radar(
	player_pos: Vector3,
	player_yaw: float,
	entity_pos: Vector3,
	range_m: float,
	radar_radius_px: float
) -> Vector2:
	if range_m <= 0.0:
		return Vector2.ZERO
	var offset := _flatten(entity_pos) - _flatten(player_pos)
	var right := _right_xz(player_yaw)
	var forward := _forward_xz(player_yaw)
	# Component along the player's right axis → radar +X; along forward → radar +Y.
	var local := Vector2(offset.dot(right), offset.dot(forward))
	var scale := radar_radius_px / range_m
	return local * scale


## True when the entity is within `range_m` of the player on the XZ plane.
## Inclusive of the boundary. Non-positive range is never on radar.
static func is_on_radar(player_pos: Vector3, entity_pos: Vector3, range_m: float) -> bool:
	if range_m <= 0.0:
		return false
	var offset := _flatten(entity_pos) - _flatten(player_pos)
	return offset.length() <= range_m


## Clamp a radar point onto the rim if it falls outside the disc, keeping its
## direction (length = radar_radius_px). Points already inside pass through
## unchanged. This is how off-range blips stick to the edge as direction arrows.
static func clamp_to_ring(radar_point: Vector2, radar_radius_px: float) -> Vector2:
	if radar_radius_px <= 0.0:
		return Vector2.ZERO
	var length := radar_point.length()
	if length <= radar_radius_px:
		return radar_point
	return radar_point / length * radar_radius_px


## Stable faction → colour mapping for blips. Unknown factions fall back to a
## neutral grey so a draw call never gets a null/garbage colour.
static func faction_color(faction: String) -> Color:
	match faction:
		"police":
			return Color(0.3, 0.55, 1.0)  # blue
		"enemy", "gang":
			return Color(0.95, 0.25, 0.22)  # red
		"mission", "objective":
			return Color(1.0, 0.85, 0.2)  # yellow
		"pedestrian":
			return Color(0.82, 0.82, 0.85)  # light grey / white
		"vehicle":
			return Color(0.3, 0.85, 0.4)  # green
		"player":
			return Color(0.4, 0.78, 1.0)  # bright cyan
		_:
			return Color(0.5, 0.5, 0.5)  # neutral grey fallback


## Map an array of {pos: Vector3, faction: String} entities to draw-ready blips:
## {point: Vector2, color: Color, on_radar: bool, clamped: Vector2}. `point` is
## the true radar position, `clamped` is pinned to the rim for off-range blips,
## and `on_radar` flags whether the entity is within range. One entry per entity,
## order preserved. Entries missing fields degrade gracefully.
static func blips(
	player_pos: Vector3, player_yaw: float, entities: Array, range_m: float, radar_radius_px: float
) -> Array:
	var out: Array = []
	for entity in entities:
		var data := entity as Dictionary
		if data == null:
			continue
		var pos: Vector3 = data.get("pos", Vector3.ZERO)
		var faction := String(data.get("faction", ""))
		var point := to_radar(player_pos, player_yaw, pos, range_m, radar_radius_px)
		var blip := {
			"point": point,
			"color": faction_color(faction),
			"on_radar": is_on_radar(player_pos, pos, range_m),
			"clamped": clamp_to_ring(point, radar_radius_px),
		}
		out.append(blip)
	return out


## Signed bearing (radians) of the entity relative to the player's facing.
## 0 = dead ahead, positive = to the player's RIGHT, negative = LEFT. Returns 0
## when the entity sits on top of the player (no meaningful direction). Result is
## in (-PI, PI].
static func bearing_to(player_pos: Vector3, player_yaw: float, entity_pos: Vector3) -> float:
	var offset := _flatten(entity_pos) - _flatten(player_pos)
	if offset.length() < 0.0001:
		return 0.0
	var right := _right_xz(player_yaw)
	var forward := _forward_xz(player_yaw)
	# atan2(right-component, forward-component): forward → 0, right → +PI/2.
	return atan2(offset.dot(right), offset.dot(forward))
