extends RefCounted
## Unit tests for GpsNavigation (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Routes are XZ-plane polylines; the
## L-shaped routes exercise turn detection (left vs right).


# A straight 20m route along +x with a midpoint waypoint.
static func _straight() -> Array:
	return [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(20, 0, 0)]


# +x for 10m, then turn toward -z for 10m. Cross.y > 0 => left turn.
static func _l_left() -> Array:
	return [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, -10)]


# +x for 10m, then turn toward +z for 10m. Cross.y < 0 => right turn.
static func _l_right() -> Array:
	return [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)]


func test_route_length_straight() -> bool:
	return is_equal_approx(GpsNavigation.route_length(_straight()), 20.0)


func test_route_length_l_shaped() -> bool:
	return is_equal_approx(GpsNavigation.route_length(_l_left()), 20.0)


func test_route_length_empty_and_single() -> bool:
	return (
		is_equal_approx(GpsNavigation.route_length([]), 0.0)
		and is_equal_approx(GpsNavigation.route_length([Vector3(3, 0, 4)]), 0.0)
	)


func test_route_length_ignores_height() -> bool:
	# Vertical offset must not inflate the planar length.
	var route := [Vector3(0, 5, 0), Vector3(10, -2, 0)]
	return is_equal_approx(GpsNavigation.route_length(route), 10.0)


func test_nearest_segment_picks_closest() -> bool:
	# Near the first leg (x in [0,10]) -> seg 0; near the second leg -> seg 1;
	# on the L's vertical leg -> seg 1. (Assertions grouped under the method cap.)
	return (
		GpsNavigation.nearest_segment(Vector3(3, 0, 1), _straight()) == 0
		and GpsNavigation.nearest_segment(Vector3(17, 0, -1), _straight()) == 1
		and GpsNavigation.nearest_segment(Vector3(10, 0, -7), _l_left()) == 1
	)


func test_distance_remaining_at_start() -> bool:
	return is_equal_approx(GpsNavigation.distance_remaining(Vector3(0, 0, 0), _straight()), 20.0)


func test_distance_remaining_mid() -> bool:
	# Projected at x=14 on segment 1: 6m left on this leg, no further segments.
	return is_equal_approx(GpsNavigation.distance_remaining(Vector3(14, 0, 2), _straight()), 6.0)


func test_distance_remaining_near_end() -> bool:
	return is_equal_approx(GpsNavigation.distance_remaining(Vector3(19.5, 0, 0), _straight()), 0.5)


func test_distance_remaining_l_route() -> bool:
	# At the corner (10,0,0): segment 0 fully done, 10m of segment 1 left.
	return is_equal_approx(GpsNavigation.distance_remaining(Vector3(10, 0, 0), _l_left()), 10.0)


func test_progress_at_start() -> bool:
	return is_equal_approx(GpsNavigation.progress(Vector3(0, 0, 0), _straight()), 0.0)


func test_progress_mid() -> bool:
	return is_equal_approx(GpsNavigation.progress(Vector3(10, 0, 0), _straight()), 0.5)


func test_progress_at_destination() -> bool:
	return is_equal_approx(GpsNavigation.progress(Vector3(20, 0, 0), _straight()), 1.0)


func test_progress_degenerate_route() -> bool:
	# Nowhere to travel -> fully complete, no division by zero.
	return is_equal_approx(GpsNavigation.progress(Vector3(0, 0, 0), [Vector3.ZERO]), 1.0)


func test_eta_basic() -> bool:
	# 20m remaining at 5 m/s -> 4s.
	return is_equal_approx(GpsNavigation.eta_seconds(Vector3(0, 0, 0), _straight(), 5.0), 4.0)


func test_eta_zero_speed_is_inf() -> bool:
	return GpsNavigation.eta_seconds(Vector3(0, 0, 0), _straight(), 0.0) == INF


func test_next_turn_left() -> bool:
	var turn := GpsNavigation.next_turn(Vector3(0, 0, 0), _l_left(), deg_to_rad(20.0))
	return (
		not turn.is_empty()
		and turn["direction"] == "left"
		and (turn["position"] as Vector3).is_equal_approx(Vector3(10, 0, 0))
		and is_equal_approx(turn["distance"], 10.0)
	)


func test_next_turn_right() -> bool:
	var turn := GpsNavigation.next_turn(Vector3(0, 0, 0), _l_right(), deg_to_rad(20.0))
	return not turn.is_empty() and turn["direction"] == "right"


func test_next_turn_none_when_straight() -> bool:
	return GpsNavigation.next_turn(Vector3(0, 0, 0), _straight(), deg_to_rad(20.0)).is_empty()


func test_next_turn_skips_passed_corner() -> bool:
	# Already on the vertical leg past the bend -> no upcoming turn.
	return GpsNavigation.next_turn(Vector3(10, 0, -5), _l_left(), deg_to_rad(20.0)).is_empty()


func test_has_arrived_at_destination() -> bool:
	return GpsNavigation.has_arrived(Vector3(20, 0, 0.5), _straight(), 1.0)


func test_has_arrived_false_except_last() -> bool:
	# Neither the start nor the midpoint waypoint counts as arrival -- only the
	# last point does. (Assertions grouped under the method cap.)
	return (
		not GpsNavigation.has_arrived(Vector3(0, 0, 0), _straight(), 1.0)
		and not GpsNavigation.has_arrived(Vector3(10, 0, 0), _straight(), 1.0)
	)


func test_direction_to_next_along_route() -> bool:
	return GpsNavigation.direction_to_next(Vector3(2, 0, 1), _straight()).is_equal_approx(
		Vector3(1, 0, 0)
	)


func test_direction_to_next_on_vertical_leg() -> bool:
	return GpsNavigation.direction_to_next(Vector3(10, 0, -3), _l_left()).is_equal_approx(
		Vector3(0, 0, -1)
	)


func test_direction_to_next_degenerate() -> bool:
	return GpsNavigation.direction_to_next(Vector3(0, 0, 0), [Vector3.ZERO]) == Vector3.ZERO
