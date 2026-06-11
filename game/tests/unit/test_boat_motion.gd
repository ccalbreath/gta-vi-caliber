extends RefCounted
## Unit tests for BoatMotion (runner contract: test_* methods return true).


func test_submerged_point_pushes_up_proportionally() -> bool:
	return absf(BoatMotion.buoyancy_force(0.4, 30.0) - 12.0) < 0.0001


func test_point_above_water_gets_no_force() -> bool:
	return BoatMotion.buoyancy_force(-0.2, 30.0) == 0.0


func test_thrust_scales_with_input_in_water() -> bool:
	return absf(BoatMotion.thrust(0.5, 9000.0, true) - 4500.0) < 0.0001


func test_thrust_is_clamped() -> bool:
	return absf(BoatMotion.thrust(4.0, 9000.0, true) - 9000.0) < 0.0001


func test_no_thrust_out_of_water() -> bool:
	return BoatMotion.thrust(1.0, 9000.0, false) == 0.0


func test_rudder_turns_in_water() -> bool:
	return absf(BoatMotion.rudder_torque(-1.0, 6000.0, true) + 6000.0) < 0.0001


func test_no_rudder_authority_out_of_water() -> bool:
	return BoatMotion.rudder_torque(1.0, 6000.0, false) == 0.0
