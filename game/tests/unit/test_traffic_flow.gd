extends RefCounted
## Unit tests for TrafficFlow (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).

const FWD := Vector3(0, 0, 1)


func test_gap_finds_car_directly_ahead() -> bool:
	var others := PackedVector3Array([Vector3(0, 0, 8)])
	return is_equal_approx(TrafficFlow.gap_ahead(Vector3.ZERO, FWD, others, 50.0, 2.0), 8.0)


func test_gap_ignores_car_behind() -> bool:
	var others := PackedVector3Array([Vector3(0, 0, -8)])
	return TrafficFlow.gap_ahead(Vector3.ZERO, FWD, others, 50.0, 2.0) >= TrafficFlow.INF_GAP


func test_gap_ignores_car_in_other_lane() -> bool:
	# 8 m ahead but 5 m to the side, lane half-width 2 → not in our lane.
	var others := PackedVector3Array([Vector3(5, 0, 8)])
	return TrafficFlow.gap_ahead(Vector3.ZERO, FWD, others, 50.0, 2.0) >= TrafficFlow.INF_GAP


func test_gap_ignores_beyond_range() -> bool:
	var others := PackedVector3Array([Vector3(0, 0, 80)])
	return TrafficFlow.gap_ahead(Vector3.ZERO, FWD, others, 50.0, 2.0) >= TrafficFlow.INF_GAP


func test_gap_picks_nearest_of_several() -> bool:
	var others := PackedVector3Array([Vector3(0, 0, 20), Vector3(0.5, 0, 6), Vector3(-0.5, 0, 12)])
	return is_equal_approx(TrafficFlow.gap_ahead(Vector3.ZERO, FWD, others, 50.0, 2.0), 6.0)


func test_gap_clear_lane_is_inf() -> bool:
	return (
		TrafficFlow.gap_ahead(Vector3.ZERO, FWD, PackedVector3Array(), 50.0, 2.0)
		>= TrafficFlow.INF_GAP
	)


func test_follow_speed_stops_when_too_close() -> bool:
	return is_equal_approx(TrafficFlow.follow_speed(10.0, 2.0, 4.0, 14.0), 0.0)


func test_follow_speed_full_when_clear() -> bool:
	return is_equal_approx(TrafficFlow.follow_speed(10.0, 20.0, 4.0, 14.0), 10.0)


func test_follow_speed_ramps_in_between() -> bool:
	# Midway between stop_gap(4) and safe_gap(14) → half speed.
	return is_equal_approx(TrafficFlow.follow_speed(10.0, 9.0, 4.0, 14.0), 5.0)


func test_follow_speed_monotonic() -> bool:
	var a := TrafficFlow.follow_speed(10.0, 6.0, 4.0, 14.0)
	var b := TrafficFlow.follow_speed(10.0, 10.0, 4.0, 14.0)
	return b > a and a >= 0.0
