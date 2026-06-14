extends RefCounted
## Unit tests for AnimRouter — the pure mapping from Locomotion states to
## AnimationTree state-machine targets, blend values and model facing.

const WALK := 5.0
const RUN := 8.5

const LAND_SKIP := 2.0


func _route(state: Locomotion.State, current: StringName, planar_speed: float = 0.0) -> StringName:
	return AnimRouter.travel_target(state, current, planar_speed, LAND_SKIP)


func test_idle_routes_to_move() -> bool:
	return _route(Locomotion.State.IDLE, AnimRouter.STATE_MOVE) == AnimRouter.STATE_MOVE


func test_walk_routes_to_move() -> bool:
	return _route(Locomotion.State.WALK, AnimRouter.STATE_MOVE, WALK) == AnimRouter.STATE_MOVE


func test_run_routes_to_move() -> bool:
	return _route(Locomotion.State.RUN, AnimRouter.STATE_MOVE, RUN) == AnimRouter.STATE_MOVE


func test_climb_routes_to_move() -> bool:
	# No climb clip in the animation library yet; the move cycle is the
	# documented placeholder so limbs keep working on ladders.
	return _route(Locomotion.State.CLIMB, AnimRouter.STATE_MOVE) == AnimRouter.STATE_MOVE


func test_jump_from_ground_starts_jump() -> bool:
	return _route(Locomotion.State.JUMP, AnimRouter.STATE_MOVE) == AnimRouter.STATE_JUMP_START


func test_jump_during_land_starts_jump() -> bool:
	# Bunny hop: a jump pressed during the landing absorb restarts the arc.
	return _route(Locomotion.State.JUMP, AnimRouter.STATE_LAND) == AnimRouter.STATE_JUMP_START


func test_rising_keeps_jump_start_playing() -> bool:
	return _route(Locomotion.State.JUMP, AnimRouter.STATE_JUMP_START) == AnimRouter.STATE_JUMP_START


func test_rising_keeps_air_loop() -> bool:
	return _route(Locomotion.State.JUMP, AnimRouter.STATE_AIR) == AnimRouter.STATE_AIR


func test_fall_lets_jump_start_finish() -> bool:
	# Past the apex the start one-shot keeps playing; the state machine
	# auto-advances it into the Air loop at its end.
	return _route(Locomotion.State.FALL, AnimRouter.STATE_JUMP_START) == AnimRouter.STATE_JUMP_START


func test_fall_off_ledge_routes_to_air() -> bool:
	# Walking off an edge without jumping skips the launch anim entirely.
	return _route(Locomotion.State.FALL, AnimRouter.STATE_MOVE) == AnimRouter.STATE_AIR


func test_slow_landing_plays_land() -> bool:
	return _route(Locomotion.State.IDLE, AnimRouter.STATE_AIR, 0.5) == AnimRouter.STATE_LAND


func test_fast_landing_skips_land() -> bool:
	# Landing while moving rolls straight back into locomotion so the legs
	# don't slide through a planted absorb pose.
	return _route(Locomotion.State.RUN, AnimRouter.STATE_AIR, RUN) == AnimRouter.STATE_MOVE


func test_short_hop_lands_from_jump_start() -> bool:
	return _route(Locomotion.State.IDLE, AnimRouter.STATE_JUMP_START, 0.0) == AnimRouter.STATE_LAND


func test_grounded_during_land_stays_in_land() -> bool:
	# The one-shot finishes on its own; the machine auto-advances to Move.
	return _route(Locomotion.State.IDLE, AnimRouter.STATE_LAND) == AnimRouter.STATE_LAND


func test_move_blend_uses_planar_speed_on_ground() -> bool:
	var blend := AnimRouter.move_blend_value(WALK, WALK, false, WALK, RUN)
	return is_equal_approx(blend, Locomotion.move_blend(WALK, WALK, RUN))


func test_move_blend_uses_total_speed_while_climbing() -> bool:
	# Ladder movement is vertical: planar speed ~0 but the limbs must cycle.
	var blend := AnimRouter.move_blend_value(0.0, 3.0, true, WALK, RUN)
	return is_equal_approx(blend, Locomotion.move_blend(3.0, WALK, RUN))


func test_dominant_point_picks_nearest() -> bool:
	var points := PackedFloat32Array([0.5, 0.8, 1.0])
	return is_equal_approx(AnimRouter.dominant_blend_point(0.55, points), 0.5)


func test_dominant_point_below_range_clamps_to_first() -> bool:
	# A slow analog walk (blend under the walk point) still belongs to the
	# walk clip — its cycle is what the legs are visibly playing.
	var points := PackedFloat32Array([0.5, 0.8, 1.0])
	return is_equal_approx(AnimRouter.dominant_blend_point(0.1, points), 0.5)


func test_dominant_point_tie_prefers_faster_clip() -> bool:
	var points := PackedFloat32Array([0.5, 0.8, 1.0])
	return is_equal_approx(AnimRouter.dominant_blend_point(0.65, points), 0.8)


func test_dominant_point_at_sprint() -> bool:
	var points := PackedFloat32Array([0.5, 0.8, 1.0])
	return is_equal_approx(AnimRouter.dominant_blend_point(1.0, points), 1.0)


func test_dominant_point_empty_points_is_nan() -> bool:
	return is_nan(AnimRouter.dominant_blend_point(0.5, PackedFloat32Array()))
