extends RefCounted
## Unit tests for NpcSteering — crowd locomotion math. Direction, the arrive
## ramp, separation falloff, clamping and waypoint advance all have to be exact
## or pedestrians jitter, overshoot, or stack on top of each other.


func test_seek_points_at_target() -> bool:
	var v := NpcSteering.seek(Vector3.ZERO, Vector3(10, 0, 0), 4.0)
	return v.is_equal_approx(Vector3(4, 0, 0))


func test_seek_ignores_height() -> bool:
	# Target 3m up but level horizontally -> no horizontal urge.
	var v := NpcSteering.seek(Vector3.ZERO, Vector3(0, 3, 0), 4.0)
	return v == Vector3.ZERO


func test_seek_zero_at_target() -> bool:
	return NpcSteering.seek(Vector3(5, 0, 5), Vector3(5, 0, 5), 4.0) == Vector3.ZERO


func test_arrive_full_speed_when_far() -> bool:
	var v := NpcSteering.arrive(Vector3.ZERO, Vector3(100, 0, 0), 4.0, 5.0)
	return absf(v.length() - 4.0) < 0.001


func test_arrive_ramps_down_in_slow_radius() -> bool:
	# Halfway into the slow radius -> half speed.
	var v := NpcSteering.arrive(Vector3.ZERO, Vector3(2.5, 0, 0), 4.0, 5.0)
	return absf(v.length() - 2.0) < 0.001


func test_arrive_stops_at_target() -> bool:
	return NpcSteering.arrive(Vector3.ZERO, Vector3(0.1, 0, 0), 4.0, 5.0) == Vector3.ZERO


func test_separation_pushes_away_from_neighbor() -> bool:
	# Neighbour to the +x side should push the NPC toward -x.
	var v := NpcSteering.separation(Vector3.ZERO, [Vector3(1, 0, 0)], 2.0, 4.0)
	return v.x < 0.0 and absf(v.z) < 0.001


func test_separation_ignores_distant_neighbors() -> bool:
	var v := NpcSteering.separation(Vector3.ZERO, [Vector3(50, 0, 0)], 2.0, 4.0)
	return v == Vector3.ZERO


func test_combine_clamps_to_max_speed() -> bool:
	var v := NpcSteering.combine([Vector3(10, 0, 0), Vector3(0, 0, 10)], [1.0, 1.0], 4.0)
	return absf(v.length() - 4.0) < 0.001


func test_advance_waypoint_skips_reached() -> bool:
	var path := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(10, 0, 0)]
	# Standing on wp0; wp1 is 1m off (within 1.5 accept) -> advance to index 2.
	var idx := NpcSteering.advance_waypoint(Vector3(0, 0, 0), path, 0, 1.5)
	return idx == 2


func test_advance_waypoint_holds_at_last() -> bool:
	var path := [Vector3(0, 0, 0), Vector3(1, 0, 0)]
	var idx := NpcSteering.advance_waypoint(Vector3(1, 0, 0), path, 1, 1.5)
	return idx == 1
