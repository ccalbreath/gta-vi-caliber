class_name TrafficFlow
extends RefCounted
## Pure car-following so ambient traffic doesn't pile through itself: a car slows
## for the nearest vehicle ahead in its own lane and stops before touching it.
##
## Static, scene-free and deterministic — unit-tested in
## tests/unit/test_traffic_flow.gd. The TrafficDirector measures the gap to each
## car's leader once per tick and caps that car's speed via follow_speed; the car
## still steers with TrafficMotion. Planar (XZ); y ignored.

const INF_GAP: float = 1.0e20


## Forward gap (m) from `pos` to the nearest point in `others` that lies ahead
## along `heading` and within `lane_half_width` of the line of travel. Cars beside
## or behind, or beyond `max_range`, are ignored. INF_GAP when the lane is clear.
static func gap_ahead(
	pos: Vector3,
	heading: Vector3,
	others: PackedVector3Array,
	max_range: float,
	lane_half_width: float
) -> float:
	var h := Vector3(heading.x, 0.0, heading.z)
	if h.length() < 0.0001:
		return INF_GAP
	h = h.normalized()
	var best := INF_GAP
	for o in others:
		var to := Vector3(o.x - pos.x, 0.0, o.z - pos.z)
		var forward := to.dot(h)
		if forward <= 0.01 or forward > max_range:
			continue
		var lateral := (to - h * forward).length()
		if lateral > lane_half_width:
			continue
		if forward < best:
			best = forward
	return best


## Target speed for a measured gap: full stop at/under stop_gap, linearly ramped
## up to desired_speed by safe_gap, desired beyond. stop_gap < safe_gap assumed;
## if not, the function still returns 0 below stop_gap and desired at/after it.
static func follow_speed(
	desired_speed: float, gap: float, stop_gap: float, safe_gap: float
) -> float:
	if gap <= stop_gap:
		return 0.0
	if gap >= safe_gap:
		return desired_speed
	var span := safe_gap - stop_gap
	if span <= 0.0:
		return desired_speed
	return desired_speed * clampf((gap - stop_gap) / span, 0.0, 1.0)
