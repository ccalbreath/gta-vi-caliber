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
