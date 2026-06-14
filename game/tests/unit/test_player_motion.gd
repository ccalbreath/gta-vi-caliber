class_name TestPlayerMotion
extends GdUnitTestSuite
## Unit tests for PlayerMotion.

const VECTOR_EPSILON := Vector3.ONE * 0.0001


func test_zero_input_gives_zero_direction() -> void:
	assert_vector(PlayerMotion.direction_from_input(Vector2.ZERO, 0.0)).is_equal(Vector3.ZERO)


func test_forward_input_points_minus_z_at_zero_yaw() -> void:
	var direction := PlayerMotion.direction_from_input(Vector2(0, -1), 0.0)
	assert_vector(direction).is_equal_approx(Vector3(0, 0, -1), VECTOR_EPSILON)


func test_direction_is_normalized_for_diagonal_input() -> void:
	var direction := PlayerMotion.direction_from_input(Vector2(1, -1), 0.0)
	assert_float(direction.length()).is_equal_approx(1.0, 0.0001)


func test_yaw_rotates_direction() -> void:
	# Forward input with a 90° yaw (counter-clockwise) should point -X.
	var direction := PlayerMotion.direction_from_input(Vector2(0, -1), PI / 2)
	assert_vector(direction).is_equal_approx(Vector3(-1, 0, 0), VECTOR_EPSILON)


func test_horizontal_velocity_scales_by_speed() -> void:
	var target := PlayerMotion.horizontal_velocity(Vector3(0, 0, -1), 5.0)
	assert_vector(target).is_equal_approx(Vector3(0, 0, -5), VECTOR_EPSILON)


func test_accelerated_preserves_vertical_velocity() -> void:
	var current := Vector3(0, -9.8, 0)
	var next := PlayerMotion.accelerated(current, Vector3(5, 0, 0), 30.0, 0.016)
	assert_float(next.y).is_equal_approx(-9.8, 0.0001)
	assert_float(next.x).is_greater(0.0)


func test_accelerated_reaches_target_eventually() -> void:
	var current := Vector3.ZERO
	var target := Vector3(5, 0, 0)
	for _i in range(100):
		current = PlayerMotion.accelerated(current, target, 30.0, 0.016)
	assert_vector(current).is_equal_approx(target, VECTOR_EPSILON)


func test_acceleration_rate_brakes_with_decel_when_no_input() -> void:
	assert_float(PlayerMotion.acceleration_rate(false, true, 30.0, 45.0, 0.35)).is_equal(45.0)


func test_acceleration_rate_uses_accel_with_input() -> void:
	assert_float(PlayerMotion.acceleration_rate(true, true, 30.0, 45.0, 0.35)).is_equal(30.0)


func test_acceleration_rate_is_scaled_in_air() -> void:
	var rate := PlayerMotion.acceleration_rate(true, false, 30.0, 45.0, 0.35)
	assert_float(rate).is_equal_approx(10.5, 0.0001)


func test_jump_fires_on_floor_with_fresh_press() -> void:
	assert_bool(PlayerMotion.should_jump(0.0, 0.12, 0.0, 0.12, false)).is_true()


func test_jump_fires_within_coyote_window() -> void:
	assert_bool(PlayerMotion.should_jump(0.1, 0.12, 0.0, 0.12, false)).is_true()


func test_jump_rejected_after_coyote_expires() -> void:
	assert_bool(PlayerMotion.should_jump(0.2, 0.12, 0.0, 0.12, false)).is_false()


func test_buffered_press_fires_on_landing() -> void:
	assert_bool(PlayerMotion.should_jump(0.0, 0.12, 0.08, 0.12, false)).is_true()


func test_stale_press_does_not_fire() -> void:
	assert_bool(PlayerMotion.should_jump(0.0, 0.12, 0.5, 0.12, false)).is_false()


func test_jump_rejected_when_already_spent() -> void:
	assert_bool(PlayerMotion.should_jump(0.0, 0.12, 0.0, 0.12, true)).is_false()


func test_climb_forward_input_goes_up() -> void:
	var v := PlayerMotion.climb_velocity(Vector2(0, -1), Vector3.ZERO, 3.0)
	assert_vector(v).is_equal_approx(Vector3(0, 3, 0), VECTOR_EPSILON)


func test_climb_back_input_goes_down() -> void:
	var v := PlayerMotion.climb_velocity(Vector2(0, 1), Vector3.ZERO, 3.0)
	assert_vector(v).is_equal_approx(Vector3(0, -3, 0), VECTOR_EPSILON)


func test_climb_without_vertical_input_hangs() -> void:
	var v := PlayerMotion.climb_velocity(Vector2.ZERO, Vector3.ZERO, 3.0)
	assert_vector(v).is_equal(Vector3.ZERO)


func test_climb_keeps_half_speed_lateral_steering() -> void:
	var v := PlayerMotion.climb_velocity(Vector2.ZERO, Vector3(1, 0, 0), 3.0)
	assert_vector(v).is_equal_approx(Vector3(1.5, 0, 0), VECTOR_EPSILON)
