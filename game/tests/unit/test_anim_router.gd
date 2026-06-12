extends RefCounted
## Unit tests for AnimRouter — the pure mapping from Locomotion states to
## AnimationTree state-machine targets, blend values and model facing.

const WALK := 5.0
const RUN := 8.5


func test_idle_routes_to_move() -> bool:
	return AnimRouter.travel_target(Locomotion.State.IDLE) == AnimRouter.STATE_MOVE


func test_walk_routes_to_move() -> bool:
	return AnimRouter.travel_target(Locomotion.State.WALK) == AnimRouter.STATE_MOVE


func test_run_routes_to_move() -> bool:
	return AnimRouter.travel_target(Locomotion.State.RUN) == AnimRouter.STATE_MOVE


func test_jump_routes_to_air() -> bool:
	return AnimRouter.travel_target(Locomotion.State.JUMP) == AnimRouter.STATE_AIR


func test_fall_routes_to_air() -> bool:
	return AnimRouter.travel_target(Locomotion.State.FALL) == AnimRouter.STATE_AIR


func test_climb_routes_to_move() -> bool:
	# No climb clip in the animation library yet; the move cycle is the
	# documented placeholder so limbs keep working on ladders.
	return AnimRouter.travel_target(Locomotion.State.CLIMB) == AnimRouter.STATE_MOVE


func test_move_blend_uses_planar_speed_on_ground() -> bool:
	var blend := AnimRouter.move_blend_value(WALK, WALK, false, WALK, RUN)
	return is_equal_approx(blend, Locomotion.move_blend(WALK, WALK, RUN))


func test_move_blend_uses_total_speed_while_climbing() -> bool:
	# Ladder movement is vertical: planar speed ~0 but the limbs must cycle.
	var blend := AnimRouter.move_blend_value(0.0, 3.0, true, WALK, RUN)
	return is_equal_approx(blend, Locomotion.move_blend(3.0, WALK, RUN))


func test_rotate_toward_caps_step() -> bool:
	return is_equal_approx(AnimRouter.rotate_toward_angle(0.0, 1.0, 0.25), 0.25)


func test_rotate_toward_reaches_target_within_step() -> bool:
	return is_equal_approx(AnimRouter.rotate_toward_angle(0.0, 0.1, 0.25), 0.1)


func test_rotate_toward_takes_shortest_arc() -> bool:
	# From just below +PI to just above -PI: the short way crosses the PI seam
	# (positive direction), not back through zero.
	var stepped := AnimRouter.rotate_toward_angle(3.0, -3.0, 0.1)
	return is_equal_approx(stepped, 3.1)


func test_facing_prefers_aim_yaw() -> bool:
	var yaw := AnimRouter.facing_target(Vector3(0.0, 0.0, 5.0), 1.2)
	return is_equal_approx(yaw, 1.2)


func test_facing_follows_travel_direction() -> bool:
	var yaw := AnimRouter.facing_target(Vector3(5.0, 0.0, 0.0), NAN)
	return is_equal_approx(yaw, atan2(5.0, 0.0))


func test_facing_keeps_current_when_still_and_unaimed() -> bool:
	return is_nan(AnimRouter.facing_target(Vector3.ZERO, NAN))


func test_facing_ignores_creep_below_idle_epsilon() -> bool:
	var creep := Vector3(0.05, 0.0, 0.0)
	return is_nan(AnimRouter.facing_target(creep, NAN))
