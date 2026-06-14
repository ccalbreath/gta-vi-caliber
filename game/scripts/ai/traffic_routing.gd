class_name TrafficRouting
extends RefCounted
## Pure road-following router for ambient traffic (issue #61). Each car gets a
## DESTINATION and the A* shortest path to it along the road graph, so it drives
## somewhere on purpose instead of wandering turn-by-turn. The node path becomes a
## string of waypoints ~WAYPOINT_STEP apart, each pushed a half-lane to the RIGHT
## of travel so opposing cars keep to opposite sides of a two-way street.
##
## Returns ABSOLUTE world waypoints (the caller shifts them into the engine frame
## via FloatingOrigin.origin_offset). Scene-free and deterministic, so it
## unit-tests headless (tests/unit/test_traffic_routing.gd).

## Waypoint spacing (m) along the path. OSM polylines run far between vertices, so
## subdivide them — a long edge still yields followable on-road points.
const WAYPOINT_STEP := 9.0


## Right-hand perpendicular of a planar heading: heading north (-Z) -> east (+X),
## matching GeoProjection's +X = east / -Z = north convention (right-hand drive).
static func right_of(heading: Vector3) -> Vector3:
	var r := Vector3(-heading.z, 0.0, heading.x)
	return r.normalized() if r.length() > 0.0001 else Vector3.ZERO


## Right-lane route from `start_pos` to the road nearest `goal_pos`, via the graph's
## A* shortest path. `heading_hint` sets the initial travel direction so the car
## sets off forward rather than reversing. Returns absolute waypoints, or empty if
## no path connects the two.
static func route_to(
	net: RoadNetwork,
	start_pos: Vector3,
	goal_pos: Vector3,
	heading_hint: Vector3,
	lane_half_width: float
) -> PackedVector3Array:
	var out := PackedVector3Array()
	if net.segment_count() == 0:
		return out
	var np := net.nearest_point(start_pos)
	var gp := net.nearest_point(goal_pos)
	if np.is_empty() or gp.is_empty():
		return out
	# Begin along the directed segment matching the car's facing, so it heads
	# toward that segment's end node rather than reversing onto the road behind it.
	var start_seg: int = np["seg"]
	var start_off: float = np["offset"]
	if heading_hint.length() > 0.001 and heading_hint.dot(np["heading"]) < 0.0:
		var rev := _reverse_segment(net, start_seg)
		if rev >= 0:
			start_off = net.seg_len[start_seg] - start_off
			start_seg = rev
	var start_node: int = net.seg_b[start_seg]
	# Aim at whichever end of the goal's segment sits closer to the destination.
	var ga: int = net.seg_a[gp["seg"]]
	var gb: int = net.seg_b[gp["seg"]]
	var to_a := net.nodes[ga].distance_to(goal_pos)
	var to_b := net.nodes[gb].distance_to(goal_pos)
	var path := net.find_path(start_node, ga if to_a <= to_b else gb)
	if path.is_empty():
		return out
	# Partial first leg: from where the car sits to its segment's end node.
	_emit_edge(
		net.nodes[net.seg_a[start_seg]], net.nodes[start_node], start_off, lane_half_width, out
	)
	for i in range(path.size() - 1):
		_emit_edge(net.nodes[path[i]], net.nodes[path[i + 1]], 0.0, lane_half_width, out)
	return out


## The segment retracing `seg` (its end node back to its start), or -1 if none.
static func _reverse_segment(net: RoadNetwork, seg: int) -> int:
	var a := net.seg_a[seg]
	var b := net.seg_b[seg]
	for cand in net.segments_from(b):
		if net.seg_b[cand] == a:
			return cand
	return -1


## Append right-lane waypoints every WAYPOINT_STEP metres along the straight edge
## a->b, starting `start_off` metres in (so the first lands ahead of the car).
static func _emit_edge(
	a: Vector3, b: Vector3, start_off: float, lane_half_width: float, out: PackedVector3Array
) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var right := right_of((b - a) / length) * lane_half_width
	var off := start_off
	while off < length - 0.01:
		off = minf(off + WAYPOINT_STEP, length)
		out.append(a.lerp(b, off / length) + right)
