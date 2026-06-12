class_name GpsNavigation
extends RefCounted
## Pure GPS / route-progress math for the minimap navigation line — the "blue
## line to the waypoint" half of GTA-style street nav. Given a precomputed
## polyline route (an Array of Vector3 waypoints, the last being the
## destination), it answers progress / distance / ETA / next-turn questions for
## a player somewhere along it.
##
## This is NOT pathfinding: NavGrid (scripts/ai/nav_grid.gd) already does A* and
## hands you the polyline. Here we only CONSUME that route and project the
## player onto it. All static, Vector3-in, scalar/Dictionary-out, no nodes, so it
## unit-tests headless (tests/unit/test_gps_navigation.gd). Work happens in the
## XZ plane (y is up); we flatten with `ground()`. Defensive throughout — empty
## or single-point routes and zero speed never produce NaN/INF surprises.

const EPS: float = 0.0001


## Drop the vertical component — navigation reasons on the ground plane.
static func ground(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Total length of the route polyline (sum of segment lengths). 0 for an empty or
## single-point route.
static func route_length(route: Array) -> float:
	var total := 0.0
	for i in range(route.size() - 1):
		total += ground((route[i + 1] as Vector3) - (route[i] as Vector3)).length()
	return total


## Index of the route segment the player is currently on — the segment whose
## nearest point to `pos` is closest. Segment i runs route[i] -> route[i + 1], so
## the index is in [0, route.size() - 2]. Returns 0 when the route is too short
## to have a segment.
static func nearest_segment(pos: Vector3, route: Array) -> int:
	if route.size() < 2:
		return 0
	var flat := ground(pos)
	var best_i := 0
	var best_d := INF
	for i in range(route.size() - 1):
		var proj := _project_point(flat, route[i] as Vector3, route[i + 1] as Vector3)
		var d := flat.distance_squared_to(proj)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


## Along-route distance from the player's projected position to the destination:
## the leftover of the current segment past the projection, plus every later
## segment. NOT straight-line. 0 for a degenerate route.
static func distance_remaining(pos: Vector3, route: Array) -> float:
	if route.size() < 2:
		return 0.0
	var flat := ground(pos)
	var seg := nearest_segment(flat, route)
	var a := route[seg] as Vector3
	var b := route[seg + 1] as Vector3
	var t := _segment_t(flat, a, b)
	var remaining := ground(b - a).length() * (1.0 - t)
	for i in range(seg + 1, route.size() - 1):
		remaining += ground((route[i + 1] as Vector3) - (route[i] as Vector3)).length()
	return remaining


## Fraction of the route completed, 0..1. 0 at the start, 1 at the destination.
## Degenerate routes report 1 (nothing left to travel).
static func progress(pos: Vector3, route: Array) -> float:
	var total := route_length(route)
	if total < EPS:
		return 1.0
	return clampf(1.0 - distance_remaining(pos, route) / total, 0.0, 1.0)


## Estimated travel time = distance_remaining / speed, in seconds. Guards a
## non-positive speed (a stopped player has no finite ETA) by returning INF.
static func eta_seconds(pos: Vector3, route: Array, speed: float) -> float:
	if speed <= EPS:
		return INF
	return distance_remaining(pos, route) / speed


## The next waypoint where the route bends by more than `turn_threshold_radians`,
## as {position: Vector3, distance: float, direction: String}. `distance` is the
## along-route distance from the player to that bend; `direction` is "left",
## "right", or "straight" from the signed turn angle (XZ, y-up). Returns {} when
## the route runs near-straight to the destination from here.
static func next_turn(pos: Vector3, route: Array, turn_threshold_radians: float) -> Dictionary:
	if route.size() < 3:
		return {}
	var flat := ground(pos)
	var seg := nearest_segment(flat, route)
	# Examine each interior waypoint ahead of the player's current segment.
	for i in range(seg + 1, route.size() - 1):
		var incoming := ground((route[i] as Vector3) - (route[i - 1] as Vector3))
		var outgoing := ground((route[i + 1] as Vector3) - (route[i] as Vector3))
		if incoming.length() < EPS or outgoing.length() < EPS:
			continue
		var signed := _signed_turn(incoming, outgoing)
		if absf(signed) <= turn_threshold_radians:
			continue
		var wp := route[i] as Vector3
		return {
			"position": wp,
			"distance": _distance_to_waypoint(flat, route, seg, i),
			"direction": "left" if signed > 0.0 else "right",
		}
	return {}


## Whether the player has reached the destination — within `arrive_radius` of the
## LAST waypoint (XZ distance). Always false for an empty route.
static func has_arrived(pos: Vector3, route: Array, arrive_radius: float) -> bool:
	if route.is_empty():
		return false
	var dest := route[route.size() - 1] as Vector3
	return ground(dest - pos).length() <= arrive_radius


## Normalized heading the player should follow right now: along the current
## segment toward its end, falling back to the segment direction when already on
## the end point. Zero vector for a degenerate route (no direction to give).
static func direction_to_next(pos: Vector3, route: Array) -> Vector3:
	if route.size() < 2:
		return Vector3.ZERO
	var flat := ground(pos)
	var seg := nearest_segment(flat, route)
	var a := route[seg] as Vector3
	var b := route[seg + 1] as Vector3
	var seg_dir := ground(b - a)
	if seg_dir.length() < EPS:
		return Vector3.ZERO
	return seg_dir.normalized()


# --- helpers -----------------------------------------------------------------


## Parameter t in [0, 1] of `p` projected onto segment a->b (clamped to the
## segment). 0 when the segment has no length.
static func _segment_t(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := ground(b - a)
	var len_sq := ab.length_squared()
	if len_sq < EPS:
		return 0.0
	return clampf(ground(p - a).dot(ab) / len_sq, 0.0, 1.0)


## Closest point on segment a->b to `p`, clamped to the segment endpoints.
static func _project_point(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var t := _segment_t(p, a, b)
	return ground(a) + ground(b - a) * t


## Signed turn angle (radians) from `incoming` to `outgoing` in the XZ plane.
## Positive = left turn, negative = right turn (y-up, screen-style). Uses the
## perpendicular dot for the sign and atan2 for a stable magnitude.
static func _signed_turn(incoming: Vector3, outgoing: Vector3) -> float:
	var a := ground(incoming)
	var b := ground(outgoing)
	if a.length() < EPS or b.length() < EPS:
		return 0.0
	# Cross product's y component: a x b about the up axis. Positive turns left.
	var cross := a.z * b.x - a.x * b.z
	var dot := a.x * b.x + a.z * b.z
	return atan2(cross, dot)


## Along-route distance from the player to waypoint index `target`, where the
## player projects onto segment `seg`. Sums the leftover of the current segment
## plus whole segments up to `target`.
static func _distance_to_waypoint(pos: Vector3, route: Array, seg: int, target: int) -> float:
	var a := route[seg] as Vector3
	var b := route[seg + 1] as Vector3
	var t := _segment_t(pos, a, b)
	var dist := ground(b - a).length() * (1.0 - t)
	for i in range(seg + 1, target):
		dist += ground((route[i + 1] as Vector3) - (route[i] as Vector3)).length()
	return dist
