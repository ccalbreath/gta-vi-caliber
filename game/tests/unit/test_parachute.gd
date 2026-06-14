extends RefCounted
## Unit tests for Parachute (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_in_freefall() -> bool:
	var p := Parachute.new()
	return p.state() == Parachute.State.FREEFALL and not p.is_deployed()


func test_freefall_accelerates_under_gravity() -> bool:
	var p := Parachute.new(55.0, 6.0)
	# 0 + 9.8 * 1.0 = 9.8 m/s after a second of freefall.
	return is_equal_approx(p.update_fall_speed(0.0, 1.0), 9.8)


func test_freefall_caps_at_terminal() -> bool:
	var p := Parachute.new(55.0, 6.0)
	# 50 + 9.8 would overshoot terminal 55 → clamps.
	return is_equal_approx(p.update_fall_speed(50.0, 1.0), 55.0)


func test_freefall_never_exceeds_terminal_big_delta() -> bool:
	var p := Parachute.new(55.0, 6.0)
	return is_equal_approx(p.update_fall_speed(10.0, 100.0), 55.0)


func test_deploy_flips_state_once() -> bool:
	var p := Parachute.new()
	var first: bool = p.deploy()
	var second: bool = p.deploy()
	return first and not second and p.is_deployed()


func test_deploy_only_from_freefall() -> bool:
	var p := Parachute.new()
	p.land()
	var opened: bool = p.deploy()
	return not opened and p.state() == Parachute.State.LANDED


func test_deployed_decelerates_toward_canopy_rate() -> bool:
	var p := Parachute.new(55.0, 6.0)
	p.deploy()
	# 50 - 12 * 1.0 = 38, still above canopy 6.
	return is_equal_approx(p.update_fall_speed(50.0, 1.0), 38.0)


func test_deployed_settles_at_canopy_rate() -> bool:
	var p := Parachute.new(55.0, 6.0)
	p.deploy()
	# 8 - 12 would undershoot canopy 6 → floors at 6.
	return is_equal_approx(p.update_fall_speed(8.0, 1.0), 6.0)


func test_deployed_speeds_up_to_canopy_if_slow() -> bool:
	var p := Parachute.new(55.0, 6.0)
	p.deploy()
	# Below canopy rate it accelerates up toward it: 0 + 12 capped at 6.
	return is_equal_approx(p.update_fall_speed(0.0, 1.0), 6.0)


func test_drift_larger_when_deployed_than_freefall() -> bool:
	var p := Parachute.new()
	var steer := Vector3(1.0, 0.0, 0.0)
	var open: Vector3 = p.horizontal_drift(steer, true, 10.0)
	var fall: Vector3 = p.horizontal_drift(steer, false, 10.0)
	return open.length() > fall.length() and fall.length() > 0.0


func test_drift_deployed_hits_glide_speed() -> bool:
	var p := Parachute.new()
	var drift: Vector3 = p.horizontal_drift(Vector3(0.0, 0.0, 3.0), true, 10.0)
	return is_equal_approx(drift.length(), 10.0) and is_equal_approx(drift.y, 0.0)


func test_drift_zero_with_no_input() -> bool:
	var p := Parachute.new()
	var drift: Vector3 = p.horizontal_drift(Vector3.ZERO, true, 10.0)
	return drift == Vector3.ZERO


func test_drift_drops_vertical_input() -> bool:
	var p := Parachute.new()
	var drift: Vector3 = p.horizontal_drift(Vector3(0.0, 9.0, 0.0), true, 10.0)
	return drift == Vector3.ZERO


func test_landing_impact_zero_for_soft_landing() -> bool:
	var p := Parachute.new()
	return is_equal_approx(p.landing_impact(4.0, 6.0), 0.0)


func test_landing_impact_rises_past_safe_speed() -> bool:
	var p := Parachute.new()
	# (9 - 6) / 6 = 0.5
	return is_equal_approx(p.landing_impact(9.0, 6.0), 0.5)


func test_landing_impact_clamped_to_one() -> bool:
	var p := Parachute.new()
	return is_equal_approx(p.landing_impact(55.0, 6.0), 1.0)


func test_landing_impact_guards_zero_safe_speed() -> bool:
	var p := Parachute.new()
	return is_equal_approx(p.landing_impact(10.0, 0.0), 1.0)


func test_is_safe_landing_threshold() -> bool:
	var p := Parachute.new()
	return p.is_safe_landing(6.0, 6.0) and not p.is_safe_landing(6.1, 6.0)


func test_time_to_ground_alt_over_rate() -> bool:
	var p := Parachute.new()
	return is_equal_approx(p.time_to_ground(60.0, 6.0), 10.0)


func test_time_to_ground_guards_zero_rate() -> bool:
	var p := Parachute.new()
	return p.time_to_ground(60.0, 0.0) == INF and is_equal_approx(p.time_to_ground(-5.0, 6.0), 0.0)


func test_land_and_reset() -> bool:
	var p := Parachute.new()
	p.deploy()
	p.land()
	var landed: bool = p.state() == Parachute.State.LANDED
	p.reset()
	return landed and p.state() == Parachute.State.FREEFALL and not p.is_deployed()
