class_name AnimRouter
extends RefCounted
## Pure routing from Locomotion states to the rig's AnimationTree.
##
## Static functions only, no scene access (docs/ARCHITECTURE.md). AnimatedRig
## stays thin: which state-machine node to travel to, where the move blend
## sits, and which yaw the model should face all resolve here so unit tests
## cover them headless. Covered by tests/unit/test_anim_router.gd.

## State-machine node names built by AnimatedRig.
const STATE_MOVE := &"Move"
const STATE_AIR := &"Air"


## The state-machine node that should be playing for a locomotion state.
## CLIMB maps to the move cycle as a documented placeholder — the animation
## library ships no ladder clip yet, and cycling limbs read better than a
## frozen pose while the player scales a ladder.
static func travel_target(state: Locomotion.State) -> StringName:
	match state:
		Locomotion.State.JUMP, Locomotion.State.FALL:
			return STATE_AIR
		_:
			return STATE_MOVE


## Blend position for the Move blend space (0 idle, 0.5 walk, 1 run).
## Grounded movement blends on planar speed; ladder movement is vertical, so
## climbing blends on total speed to keep the limbs cycling.
static func move_blend_value(
	planar_speed: float, total_speed: float, is_climbing: bool, walk_speed: float, run_speed: float
) -> float:
	var speed := total_speed if is_climbing else planar_speed
	return Locomotion.move_blend(speed, walk_speed, run_speed)


## Step an angle toward a target along the shortest arc, capped at max_step.
static func rotate_toward_angle(current: float, target: float, max_step: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	return current + clampf(diff, -max_step, max_step)


## Yaw the model should face this frame: the weapon aim when one is active
## (so strafing reads third-person-shooter), else the travel direction, else
## NAN meaning "keep the current facing" (standing still doesn't snap).
static func facing_target(planar_velocity: Vector3, aim_yaw: float) -> float:
	if not is_nan(aim_yaw):
		return aim_yaw
	var planar_speed := planar_velocity.length()
	if planar_speed > Locomotion.IDLE_SPEED_EPSILON:
		return atan2(planar_velocity.x, planar_velocity.z)
	return NAN
