class_name PlayerMotion
extends RefCounted
## Pure movement math for the player controller.
##
## Static functions only, no scene access — this is the pattern for testable
## logic (docs/ARCHITECTURE.md): Player stays thin, the math lives here and
## is covered by tests/unit/test_player_motion.gd.


## Convert 2D input (from Input.get_vector) into a world-space direction,
## rotated so "forward" follows the camera yaw. Returns a unit vector or ZERO.
static func direction_from_input(input_dir: Vector2, camera_yaw: float) -> Vector3:
	if input_dir.is_zero_approx():
		return Vector3.ZERO
	var local := Vector3(input_dir.x, 0.0, input_dir.y)
	return local.rotated(Vector3.UP, camera_yaw).normalized()


## Target horizontal velocity for a direction and speed (y is always 0).
static func horizontal_velocity(direction: Vector3, speed: float) -> Vector3:
	return Vector3(direction.x * speed, 0.0, direction.z * speed)


## Move the current horizontal velocity toward the target, leaving y intact.
static func accelerated(
	current: Vector3, target: Vector3, acceleration: float, delta: float
) -> Vector3:
	return Vector3(
		move_toward(current.x, target.x, acceleration * delta),
		current.y,
		move_toward(current.z, target.z, acceleration * delta)
	)
