extends RefCounted
## Unit tests for VehicleMotion.rollover_steer_limit (runner contract: test_*
## methods return true). Split out of test_vehicle_motion.gd to keep each suite
## under the public-method lint cap.


func test_rollover_limit_is_unconstrained_when_parked() -> bool:
	return VehicleMotion.rollover_steer_limit(0.0, 1.7, 0.3, 2.9, 0.8) >= TAU


func test_rollover_limit_tightens_with_speed() -> bool:
	var slow := VehicleMotion.rollover_steer_limit(10.0, 1.7, 0.3, 2.9, 0.8)
	var fast := VehicleMotion.rollover_steer_limit(30.0, 1.7, 0.3, 2.9, 0.8)
	return fast < slow


func test_rollover_limit_widens_with_lower_cg() -> bool:
	var tall := VehicleMotion.rollover_steer_limit(20.0, 1.7, 0.6, 2.9, 0.8)
	var low := VehicleMotion.rollover_steer_limit(20.0, 1.7, 0.3, 2.9, 0.8)
	return low > tall


func test_rollover_limit_widens_with_wider_track() -> bool:
	var narrow := VehicleMotion.rollover_steer_limit(20.0, 1.0, 0.3, 2.9, 0.8)
	var wide := VehicleMotion.rollover_steer_limit(20.0, 1.7, 0.3, 2.9, 0.8)
	return wide > narrow


func test_rollover_limit_scales_with_margin() -> bool:
	var cautious := VehicleMotion.rollover_steer_limit(20.0, 1.7, 0.3, 2.9, 0.5)
	var confident := VehicleMotion.rollover_steer_limit(20.0, 1.7, 0.3, 2.9, 1.0)
	return confident > cautious


func test_rollover_limit_degenerate_cg_is_unconstrained() -> bool:
	return VehicleMotion.rollover_steer_limit(20.0, 1.7, 0.0, 2.9, 0.8) >= TAU
