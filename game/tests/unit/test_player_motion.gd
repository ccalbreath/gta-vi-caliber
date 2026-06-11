extends RefCounted
## Unit tests for PlayerMotion (see tests/run_tests.gd for the runner
## contract: test_* methods return true to pass).


func test_zero_input_gives_zero_direction() -> bool:
	return PlayerMotion.direction_from_input(Vector2.ZERO, 0.0) == Vector3.ZERO


func test_forward_input_points_minus_z_at_zero_yaw() -> bool:
	var direction := PlayerMotion.direction_from_input(Vector2(0, -1), 0.0)
	return direction.is_equal_approx(Vector3(0, 0, -1))


func test_direction_is_normalized_for_diagonal_input() -> bool:
	var direction := PlayerMotion.direction_from_input(Vector2(1, -1), 0.0)
	return absf(direction.length() - 1.0) < 0.0001


func test_yaw_rotates_direction() -> bool:
	# Forward input with a 90° yaw (counter-clockwise) should point -X.
	var direction := PlayerMotion.direction_from_input(Vector2(0, -1), PI / 2)
	return direction.is_equal_approx(Vector3(-1, 0, 0))


func test_horizontal_velocity_scales_by_speed() -> bool:
	var target := PlayerMotion.horizontal_velocity(Vector3(0, 0, -1), 5.0)
	return target.is_equal_approx(Vector3(0, 0, -5))


func test_accelerated_preserves_vertical_velocity() -> bool:
	var current := Vector3(0, -9.8, 0)
	var next := PlayerMotion.accelerated(current, Vector3(5, 0, 0), 30.0, 0.016)
	return absf(next.y + 9.8) < 0.0001 and next.x > 0.0


func test_accelerated_reaches_target_eventually() -> bool:
	var current := Vector3.ZERO
	var target := Vector3(5, 0, 0)
	for _i in range(100):
		current = PlayerMotion.accelerated(current, target, 30.0, 0.016)
	return current.is_equal_approx(target)


func test_acceleration_rate_brakes_with_decel_when_no_input() -> bool:
	return PlayerMotion.acceleration_rate(false, true, 30.0, 45.0, 0.35) == 45.0


func test_acceleration_rate_uses_accel_with_input() -> bool:
	return PlayerMotion.acceleration_rate(true, true, 30.0, 45.0, 0.35) == 30.0


func test_acceleration_rate_is_scaled_in_air() -> bool:
	var rate := PlayerMotion.acceleration_rate(true, false, 30.0, 45.0, 0.35)
	return absf(rate - 10.5) < 0.0001


func test_jump_fires_on_floor_with_fresh_press() -> bool:
	return PlayerMotion.should_jump(0.0, 0.12, 0.0, 0.12, false)


func test_jump_fires_within_coyote_window() -> bool:
	return PlayerMotion.should_jump(0.1, 0.12, 0.0, 0.12, false)


func test_jump_rejected_after_coyote_expires() -> bool:
	return not PlayerMotion.should_jump(0.2, 0.12, 0.0, 0.12, false)


func test_buffered_press_fires_on_landing() -> bool:
	return PlayerMotion.should_jump(0.0, 0.12, 0.08, 0.12, false)


func test_stale_press_does_not_fire() -> bool:
	return not PlayerMotion.should_jump(0.0, 0.12, 0.5, 0.12, false)


func test_jump_rejected_when_already_spent() -> bool:
	return not PlayerMotion.should_jump(0.0, 0.12, 0.0, 0.12, true)


func test_climb_forward_input_goes_up() -> bool:
	var v := PlayerMotion.climb_velocity(Vector2(0, -1), Vector3.ZERO, 3.0)
	return v.is_equal_approx(Vector3(0, 3, 0))


func test_climb_back_input_goes_down() -> bool:
	var v := PlayerMotion.climb_velocity(Vector2(0, 1), Vector3.ZERO, 3.0)
	return v.is_equal_approx(Vector3(0, -3, 0))


func test_climb_without_vertical_input_hangs() -> bool:
	var v := PlayerMotion.climb_velocity(Vector2.ZERO, Vector3.ZERO, 3.0)
	return v.is_equal_approx(Vector3.ZERO)


func test_climb_keeps_half_speed_lateral_steering() -> bool:
	var v := PlayerMotion.climb_velocity(Vector2.ZERO, Vector3(1, 0, 0), 3.0)
	return v.is_equal_approx(Vector3(1.5, 0, 0))


func test_slope_slide_flat_ground_is_zero() -> bool:
	return PlayerMotion.slope_slide(Vector3.UP, 0.82, 18.0) == Vector3.ZERO


func test_slope_slide_points_down_the_fall_line() -> bool:
	# A normal tilted toward +X (ramp rising toward -X): the fall line is +X.
	var slide := PlayerMotion.slope_slide(Vector3(0.707, 0.707, 0.0), 0.82, 18.0)
	return slide.x > 0.0 and absf(slide.z) < 0.0001 and slide.y == 0.0


func test_slope_slide_is_horizontal() -> bool:
	var slide := PlayerMotion.slope_slide(Vector3(0.5, 0.6, 0.6).normalized(), 0.82, 18.0)
	return slide.y == 0.0


func test_slope_slide_grows_with_steepness() -> bool:
	var gentle := PlayerMotion.slope_slide(Vector3(0.3, 0.81, 0.0).normalized(), 0.82, 18.0)
	var steep := PlayerMotion.slope_slide(Vector3(0.9, 0.3, 0.0).normalized(), 0.82, 18.0)
	return steep.length() > gentle.length()


func test_slope_slide_not_steep_enough_is_zero() -> bool:
	return PlayerMotion.slope_slide(Vector3(0.0, 0.95, 0.0), 0.82, 18.0) == Vector3.ZERO
