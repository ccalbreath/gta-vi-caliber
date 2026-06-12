class_name VehicleMotion
extends RefCounted
## Pure vehicle-control math for Car.
##
## Static functions only, no scene access — same testable-core pattern as
## PlayerMotion (docs/ARCHITECTURE.md). Covered by
## tests/unit/test_vehicle_motion.gd.


## Convert two opposing input strengths into a signed driving axis.
## Positive means forward/right; negative means back/left.
static func driving_axis(negative_strength: float, positive_strength: float) -> float:
	return clampf(positive_strength - negative_strength, -1.0, 1.0)


## Godot VehicleBody3D applies positive engine_force along +Z. This project
## authors vehicle noses toward -Z, so project-forward wheel force must be
## inverted at the engine_force boundary.
static func godot_engine_force(project_forward_force: float) -> float:
	return -project_forward_force


## Positive project steering means turn right. Godot VehicleBody3D positive
## steering turns left for this vehicle setup, so invert at the boundary.
static func godot_steering(project_right_steer: float) -> float:
	return -project_right_steer


## Engine force for a throttle input, tapering linearly to zero as the car
## approaches top speed so acceleration feels strong from a standstill and
## the car doesn't accelerate forever.
static func engine_force(
	throttle: float, max_force: float, speed: float, top_speed: float
) -> float:
	if top_speed <= 0.0:
		return 0.0
	var headroom := clampf(1.0 - speed / top_speed, 0.0, 1.0)
	return clampf(throttle, -1.0, 1.0) * max_force * headroom


## Maximum steering angle available at a speed: full lock when parked,
## tightening as speed rises so highway driving doesn't spin out.
static func steer_limit(speed: float, max_steer: float, falloff_speed: float) -> float:
	return max_steer / (1.0 + maxf(speed, 0.0) / maxf(falloff_speed, 0.001))


## Steering angle above which a corner would lift the inside wheels: the
## rollover threshold. Lateral acceleration in a steady corner is
## v²·tan(steer)/wheelbase; the chassis starts to roll over once that exceeds
## g·(track/2)/cg_height. Solving for the steer angle (with a safety margin
## <1 applied to the threshold) gives the largest angle that keeps the
## vehicle on all wheels at this speed. Unconstrained at low speed.
static func rollover_steer_limit(
	speed: float, track: float, cg_height: float, wheelbase: float, margin: float
) -> float:
	if speed < 0.001 or cg_height < 0.001:
		return TAU
	var max_lateral_accel := 9.81 * (track * 0.5) / cg_height * margin
	return atan(max_lateral_accel * wheelbase / (speed * speed))


## Target steering angle for an input, respecting the speed-sensitive limit.
static func steer_target(
	input: float, speed: float, max_steer: float, falloff_speed: float
) -> float:
	return godot_steering(clampf(input, -1.0, 1.0)) * steer_limit(speed, max_steer, falloff_speed)


## PD-controller torque that rights a two-wheeler: pushes against the tilt
## error (spring toward upright/lean target) and against the roll rate
## (damping, so it settles instead of wobbling).
static func upright_torque(
	tilt_error: float, roll_rate: float, stiffness: float, damping: float
) -> float:
	return -stiffness * tilt_error - damping * roll_rate
