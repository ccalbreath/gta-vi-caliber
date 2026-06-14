class_name TrafficRouting
extends RefCounted
## Pure road-following router for ambient traffic (issue #61). Given a built
## RoadNetwork and where a car is (plus the way it faces), it walks the graph
## segment -> segment, picking a continuation at each junction (never an immediate
## U-turn, biased toward going straight), until the route is at least `min_length`
## metres long. Every waypoint is pushed `lane_half_width` metres to the RIGHT of
## travel, so opposing cars keep to opposite sides of a two-way street.
##
## Returns ABSOLUTE world waypoints (the caller shifts them into the engine frame
## via FloatingOrigin.origin_offset). Scene-free and deterministic given the same
## RNG, so it unit-tests headless (tests/unit/test_traffic_routing.gd).

const MAX_SEGMENTS := 256
## Waypoint spacing (m) along a segment. OSM polylines can run far between
## vertices, so subdivide them — one long segment still yields a string of
## on-road points the car can follow, not a single distant node.
const WAYPOINT_STEP := 9.0


## Right-hand perpendicular of a planar heading: heading north (-Z) -> east (+X),
## matching GeoProjection's +X = east / -Z = north convention (right-hand drive).
static func right_of(heading: Vector3) -> Vector3:
	var r := Vector3(-heading.z, 0.0, heading.x)
	return r.normalized() if r.length() > 0.0001 else Vector3.ZERO


## Build a right-lane route along the road graph from `anchor_pos`, heading the
## way `heading_hint` points. Returns absolute waypoints (the node ahead first,
## then each junction onward). Empty if the graph has no roads.
static func route_points(
	net: RoadNetwork,
	anchor_pos: Vector3,
	heading_hint: Vector3,
	min_length: float,
	rng: RandomNumberGenerator,
	lane_half_width: float
) -> PackedVector3Array:
	var out := PackedVector3Array()
	if net.segment_count() == 0:
		return out
	var np := net.nearest_point(anchor_pos)
	if np.is_empty():
		return out
	# Start along the directed segment that matches the way the car is facing, so
	# it continues forward instead of reversing onto the road it came from. The
	# start offset is where the car sits on that segment, so the first waypoint
	# lands just ahead of it rather than back at the segment's start node.
	var seg: int = np["seg"]
	var start_off: float = np["offset"]
	if heading_hint.length() > 0.001 and heading_hint.dot(np["heading"]) < 0.0:
		var rev := _reverse_segment(net, seg)
		if rev >= 0:
			start_off = net.seg_len[seg] - start_off
			seg = rev
	var travelled := 0.0
	var guard := 0
	while travelled < min_length and guard < MAX_SEGMENTS:
		guard += 1
		var seg_length: float = net.seg_len[seg]
		var right := right_of(net.point_on_segment(seg, 0.0)["heading"]) * lane_half_width
		var off := start_off
		while off < seg_length - 0.01:
			off = minf(off + WAYPOINT_STEP, seg_length)
			out.append(net.point_on_segment(seg, off)["pos"] + right)
		travelled += maxf(seg_length - start_off, 0.0)
		start_off = 0.0
		seg = _next_segment(net, seg, rng)
		if seg < 0:
			break
	return out


## The segment that retraces `seg` (its end node back to its start), or -1 if the
## graph has no reverse (it normally does — polylines are added both ways).
static func _reverse_segment(net: RoadNetwork, seg: int) -> int:
	var a := net.seg_a[seg]
	var b := net.seg_b[seg]
	for cand in net.segments_from(b):
		if net.seg_b[cand] == a:
			return cand
	return -1


## Pick a continuation leaving the end node of `seg`, excluding the immediate
## U-turn (the reverse segment). Returns -1 at a dead end. Weights straighter
## continuations more heavily so cars mostly go straight and only sometimes turn.
static func _next_segment(net: RoadNetwork, seg: int, rng: RandomNumberGenerator) -> int:
	var end_node := net.seg_b[seg]
	var came_from := net.seg_a[seg]
	var heading: Vector3 = net.point_on_segment(seg, 0.0)["heading"]
	var options := PackedInt32Array()
	for cand in net.segments_from(end_node):
		if net.seg_b[cand] != came_from:
			options.append(cand)
	if options.is_empty():
		# Dead end: allow the U-turn rather than freezing the car.
		return net.segments_from(end_node)[0] if net.segments_from(end_node).size() > 0 else -1
	var weights := PackedFloat32Array()
	var total := 0.0
	for cand in options:
		var ch: Vector3 = net.point_on_segment(cand, 0.0)["heading"]
		# 1.0 dead-straight .. ~0.05 hairpin; squared so straight is strongly favoured.
		var straight := maxf(0.05, 0.5 + 0.5 * heading.dot(ch))
		var w := straight * straight
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in options.size():
		pick -= weights[i]
		if pick <= 0.0:
			return options[i]
	return options[options.size() - 1]
