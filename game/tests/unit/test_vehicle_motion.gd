class_name TestVehicleMotion
extends GdUnitTestSuite
## Unit tests for VehicleMotion.


func test_full_throttle_at_standstill_gives_max_force() -> void:
	assert_float(VehicleMotion.engine_force(1.0, 2600.0, 0.0, 38.0)).is_equal_approx(2600.0, 0.0001)


func test_force_tapers_to_zero_at_top_speed() -> void:
	assert_float(VehicleMotion.engine_force(1.0, 2600.0, 38.0, 38.0)).is_equal_approx(0.0, 0.0001)


func test_force_is_half_at_half_top_speed() -> void:
	assert_float(VehicleMotion.engine_force(1.0, 2600.0, 19.0, 38.0)).is_equal_approx(
		1300.0, 0.0001
	)


func test_reverse_throttle_gives_negative_force() -> void:
	assert_float(VehicleMotion.engine_force(-1.0, 2600.0, 0.0, 38.0)).is_less(0.0)


func test_throttle_is_clamped() -> void:
	assert_float(VehicleMotion.engine_force(5.0, 2600.0, 0.0, 38.0)).is_equal_approx(2600.0, 0.0001)


func test_degenerate_top_speed_gives_no_force() -> void:
	assert_float(VehicleMotion.engine_force(1.0, 2600.0, 10.0, 0.0)).is_equal(0.0)


func test_steer_limit_is_full_lock_when_parked() -> void:
	assert_float(VehicleMotion.steer_limit(0.0, 0.55, 12.0)).is_equal_approx(0.55, 0.0001)


func test_steer_limit_halves_at_falloff_speed() -> void:
	assert_float(VehicleMotion.steer_limit(12.0, 0.55, 12.0)).is_equal_approx(0.275, 0.0001)


func test_steer_target_scales_input() -> void:
	assert_float(VehicleMotion.steer_target(0.5, 0.0, 0.55, 12.0)).is_equal_approx(0.275, 0.0001)


func test_steer_target_clamps_input() -> void:
	assert_float(VehicleMotion.steer_target(3.0, 0.0, 0.55, 12.0)).is_equal_approx(0.55, 0.0001)


func test_upright_torque_opposes_tilt() -> void:
	# Tilted positive with no roll rate: torque must push negative.
	assert_float(VehicleMotion.upright_torque(0.5, 0.0, 90.0, 12.0)).is_less(0.0)


func test_upright_torque_damps_roll_rate() -> void:
	# Upright but rolling: torque must oppose the roll.
	assert_float(VehicleMotion.upright_torque(0.0, 2.0, 90.0, 12.0)).is_less(0.0)


func test_upright_torque_is_zero_at_rest_upright() -> void:
	assert_float(VehicleMotion.upright_torque(0.0, 0.0, 90.0, 12.0)).is_equal(0.0)


func test_upright_torque_scales_with_stiffness() -> void:
	var soft := VehicleMotion.upright_torque(0.5, 0.0, 45.0, 12.0)
	var stiff := VehicleMotion.upright_torque(0.5, 0.0, 90.0, 12.0)
	assert_float(stiff).is_equal_approx(2.0 * soft, 0.0001)
