extends RefCounted
## Unit tests for TrafficRules (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).

const FWD := Vector3(0, 0, 1)


func test_right_of_heading_z_is_neg_x() -> bool:
	# Facing +Z with +Y up, the driver's right is -X.
	return TrafficRules.right_of(FWD).is_equal_approx(Vector3(-1, 0, 0))


func test_right_of_is_unit() -> bool:
	return is_equal_approx(TrafficRules.right_of(Vector3(1, 0, 1)).length(), 1.0)


func test_is_on_right_true() -> bool:
	# Facing +Z, right is -X, so a car at -X is on the right.
	return TrafficRules.is_on_right(FWD, Vector3(-3, 0, 1))


func test_is_on_right_false_for_left() -> bool:
	return not TrafficRules.is_on_right(FWD, Vector3(3, 0, 1))


func test_should_yield_to_car_on_right() -> bool:
	# Other at -X (our right), within range, ahead → yield.
	return TrafficRules.should_yield(Vector3.ZERO, FWD, Vector3(-4, 0, 3), false, 20.0)


func test_no_yield_to_car_on_left() -> bool:
	return not TrafficRules.should_yield(Vector3.ZERO, FWD, Vector3(4, 0, 3), false, 20.0)


func test_no_yield_when_out_of_range() -> bool:
	return not TrafficRules.should_yield(Vector3.ZERO, FWD, Vector3(-4, 0, 40), false, 20.0)


func test_no_yield_to_car_behind() -> bool:
	# Other on our right side but well behind us → already cleared, don't yield.
	return not TrafficRules.should_yield(Vector3.ZERO, FWD, Vector3(-2, 0, -10), false, 20.0)


func test_yield_to_car_in_junction_regardless_of_side() -> bool:
	# Car on our left but already in the junction → still yield.
	return TrafficRules.should_yield(Vector3.ZERO, FWD, Vector3(4, 0, 3), true, 20.0)
