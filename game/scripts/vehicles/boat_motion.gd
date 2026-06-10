class_name BoatMotion
extends RefCounted
## Pure buoyancy and boat-control math for Boat.
##
## Static functions only, no scene access — same testable-core pattern as
## VehicleMotion. Covered by tests/unit/test_boat_motion.gd.


## Upward force for one float point: proportional to how deep the point sits
## below the water line, zero once it clears the surface.
static func buoyancy_force(depth: float, strength: float) -> float:
	return maxf(depth, 0.0) * strength


## Propeller thrust: only bites while the hull is in the water.
static func thrust(input: float, max_thrust: float, submerged: bool) -> float:
	if not submerged:
		return 0.0
	return clampf(input, -1.0, 1.0) * max_thrust


## Rudder yaw torque: same rule — no water, no authority.
static func rudder_torque(input: float, max_torque: float, submerged: bool) -> float:
	if not submerged:
		return 0.0
	return clampf(input, -1.0, 1.0) * max_torque
