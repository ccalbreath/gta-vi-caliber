class_name TestVehicleMotionAir
extends GdUnitTestSuite
## Unit tests for VehicleMotion's airborne dynamics: air-righting and wheelies.
## Split from TestVehicleMotion to keep each suite under the public-method cap.

const VECTOR_EPSILON := Vector3.ONE * 0.0001


func test_air_righting_zero_when_level_and_still() -> void:
	assert_vector(VehicleMotion.air_righting_torque(Vector3.UP, Vector3.ZERO, 5.0, 0.5)).is_equal(
		Vector3.ZERO
	)


func test_air_righting_opposes_roll_tilt() -> void:
	# Up tilted toward +X (rolled): righting axis is +Z, no X component.
	var torque := VehicleMotion.air_righting_torque(
		Vector3(0.707, 0.707, 0.0), Vector3.ZERO, 5.0, 0.5
	)
	assert_float(torque.z).is_greater(0.0)
	assert_float(torque.x).is_equal_approx(0.0, 0.0001)


func test_air_righting_damps_spin_when_level() -> void:
	var torque := VehicleMotion.air_righting_torque(Vector3.UP, Vector3(0.0, 2.0, 0.0), 5.0, 0.5)
	assert_vector(torque).is_equal_approx(Vector3(0.0, -1.0, 0.0), VECTOR_EPSILON)


func test_air_righting_grows_with_tilt() -> void:
	var small := VehicleMotion.air_righting_torque(
		Vector3(0.2, 0.98, 0.0).normalized(), Vector3.ZERO, 5.0, 0.5
	)
	var big := VehicleMotion.air_righting_torque(
		Vector3(0.8, 0.6, 0.0).normalized(), Vector3.ZERO, 5.0, 0.5
	)
	assert_float(big.length()).is_greater(small.length())


func test_wheelie_none_below_threshold() -> void:
	assert_float(VehicleMotion.wheelie_torque(5.0, 6.0, 8.0, 90.0)).is_equal(0.0)


func test_wheelie_none_when_braking() -> void:
	assert_float(VehicleMotion.wheelie_torque(-10.0, 6.0, 8.0, 90.0)).is_equal(0.0)


func test_wheelie_ramps_past_threshold() -> void:
	# (8 - 6) * 8 = 16.
	assert_float(VehicleMotion.wheelie_torque(8.0, 6.0, 8.0, 90.0)).is_equal_approx(16.0, 0.0001)


func test_wheelie_caps_at_max() -> void:
	assert_float(VehicleMotion.wheelie_torque(100.0, 6.0, 8.0, 90.0)).is_equal(90.0)
