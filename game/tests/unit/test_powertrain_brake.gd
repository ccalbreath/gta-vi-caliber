extends RefCounted
## Unit tests for Powertrain.engine_brake — the off-throttle engine drag that
## slows a coasting car (split from test_powertrain.gd to stay under the
## per-class method cap). See tests/run_tests.gd: test_* methods return true.

const REDLINE := 6500.0
const FIRST := 3.40
const TOP := 0.85
const MAX_BRAKE := 6.0


func test_engine_brake_zero_at_zero_revs() -> bool:
	return is_equal_approx(Powertrain.engine_brake(0.0, REDLINE, FIRST, FIRST, MAX_BRAKE), 0.0)


func test_engine_brake_grows_with_revs() -> bool:
	var low := Powertrain.engine_brake(2000.0, REDLINE, FIRST, FIRST, MAX_BRAKE)
	var high := Powertrain.engine_brake(5000.0, REDLINE, FIRST, FIRST, MAX_BRAKE)
	return high > low


func test_engine_brake_stronger_in_lower_gear() -> bool:
	var first := Powertrain.engine_brake(4000.0, REDLINE, FIRST, FIRST, MAX_BRAKE)
	var top := Powertrain.engine_brake(4000.0, REDLINE, TOP, FIRST, MAX_BRAKE)
	return first > top


func test_engine_brake_caps_in_first_at_redline() -> bool:
	return is_equal_approx(
		Powertrain.engine_brake(REDLINE, REDLINE, FIRST, FIRST, MAX_BRAKE), MAX_BRAKE
	)


func test_engine_brake_never_negative() -> bool:
	return Powertrain.engine_brake(3000.0, REDLINE, TOP, FIRST, MAX_BRAKE) >= 0.0


func test_engine_brake_safe_with_zero_redline() -> bool:
	return is_equal_approx(Powertrain.engine_brake(3000.0, 0.0, FIRST, FIRST, MAX_BRAKE), 0.0)
