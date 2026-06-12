extends RefCounted
## Unit tests for VehicleMotion (runner contract: test_* methods return true).


func test_driving_axis_forward_or_right_is_positive() -> bool:
	return VehicleMotion.driving_axis(0.0, 1.0) == 1.0


func test_driving_axis_back_or_left_is_negative() -> bool:
	return VehicleMotion.driving_axis(1.0, 0.0) == -1.0


func test_driving_axis_opposed_inputs_cancel() -> bool:
	return VehicleMotion.driving_axis(1.0, 1.0) == 0.0


func test_driving_axis_clamps_to_unit_range() -> bool:
	return (
		VehicleMotion.driving_axis(0.0, 4.0) == 1.0 and VehicleMotion.driving_axis(4.0, 0.0) == -1.0
	)


func test_project_controls_invert_for_godot_vehicle_body() -> bool:
	return (
		VehicleMotion.godot_engine_force(1200.0) == -1200.0
		and VehicleMotion.godot_engine_force(-800.0) == 800.0
		and VehicleMotion.godot_steering(0.5) == -0.5
		and VehicleMotion.godot_steering(-0.25) == 0.25
	)


func test_full_throttle_at_standstill_gives_max_force() -> bool:
	return absf(VehicleMotion.engine_force(1.0, 2600.0, 0.0, 38.0) - 2600.0) < 0.0001


func test_force_tapers_to_zero_at_top_speed() -> bool:
	return absf(VehicleMotion.engine_force(1.0, 2600.0, 38.0, 38.0)) < 0.0001


func test_force_is_half_at_half_top_speed() -> bool:
	return absf(VehicleMotion.engine_force(1.0, 2600.0, 19.0, 38.0) - 1300.0) < 0.0001


func test_reverse_throttle_gives_negative_force() -> bool:
	return VehicleMotion.engine_force(-1.0, 2600.0, 0.0, 38.0) < 0.0


func test_throttle_is_clamped() -> bool:
	return absf(VehicleMotion.engine_force(5.0, 2600.0, 0.0, 38.0) - 2600.0) < 0.0001


func test_degenerate_top_speed_gives_no_force() -> bool:
	return VehicleMotion.engine_force(1.0, 2600.0, 10.0, 0.0) == 0.0


func test_steer_limit_is_full_lock_when_parked() -> bool:
	return absf(VehicleMotion.steer_limit(0.0, 0.55, 12.0) - 0.55) < 0.0001


func test_steer_limit_halves_at_falloff_speed() -> bool:
	return absf(VehicleMotion.steer_limit(12.0, 0.55, 12.0) - 0.275) < 0.0001


func test_steer_target_scales_input() -> bool:
	return absf(VehicleMotion.steer_target(0.5, 0.0, 0.55, 12.0) + 0.275) < 0.0001


func test_steer_target_clamps_input() -> bool:
	return absf(VehicleMotion.steer_target(3.0, 0.0, 0.55, 12.0) + 0.55) < 0.0001


func test_upright_torque_opposes_tilt() -> bool:
	# Tilted positive with no roll rate: torque must push negative.
	return VehicleMotion.upright_torque(0.5, 0.0, 90.0, 12.0) < 0.0


func test_upright_torque_damps_roll_rate() -> bool:
	# Upright but rolling: torque must oppose the roll.
	return VehicleMotion.upright_torque(0.0, 2.0, 90.0, 12.0) < 0.0


func test_upright_torque_is_zero_at_rest_upright() -> bool:
	return VehicleMotion.upright_torque(0.0, 0.0, 90.0, 12.0) == 0.0


func test_upright_torque_scales_with_stiffness() -> bool:
	var soft := VehicleMotion.upright_torque(0.5, 0.0, 45.0, 12.0)
	var stiff := VehicleMotion.upright_torque(0.5, 0.0, 90.0, 12.0)
	return absf(stiff - 2.0 * soft) < 0.0001


func test_air_righting_zero_when_level_and_still() -> bool:
	return VehicleMotion.air_righting_torque(Vector3.UP, Vector3.ZERO, 5.0, 0.5) == Vector3.ZERO


func test_air_righting_opposes_roll_tilt() -> bool:
	# Up tilted toward +X (rolled): righting axis is +Z, no X component.
	var torque := VehicleMotion.air_righting_torque(
		Vector3(0.707, 0.707, 0.0), Vector3.ZERO, 5.0, 0.5
	)
	return torque.z > 0.0 and absf(torque.x) < 0.0001


func test_air_righting_damps_spin_when_level() -> bool:
	var torque := VehicleMotion.air_righting_torque(Vector3.UP, Vector3(0.0, 2.0, 0.0), 5.0, 0.5)
	return torque.is_equal_approx(Vector3(0.0, -1.0, 0.0))


func test_air_righting_grows_with_tilt() -> bool:
	var small := VehicleMotion.air_righting_torque(
		Vector3(0.2, 0.98, 0.0).normalized(), Vector3.ZERO, 5.0, 0.5
	)
	var big := VehicleMotion.air_righting_torque(
		Vector3(0.8, 0.6, 0.0).normalized(), Vector3.ZERO, 5.0, 0.5
	)
	return big.length() > small.length()


func test_wheelie_none_below_threshold() -> bool:
	return VehicleMotion.wheelie_torque(5.0, 6.0, 8.0, 90.0) == 0.0


func test_wheelie_none_when_braking() -> bool:
	return VehicleMotion.wheelie_torque(-10.0, 6.0, 8.0, 90.0) == 0.0


func test_wheelie_ramps_past_threshold() -> bool:
	# (8 - 6) * 8 = 16.
	return absf(VehicleMotion.wheelie_torque(8.0, 6.0, 8.0, 90.0) - 16.0) < 0.0001


func test_wheelie_caps_at_max() -> bool:
	return VehicleMotion.wheelie_torque(100.0, 6.0, 8.0, 90.0) == 90.0
