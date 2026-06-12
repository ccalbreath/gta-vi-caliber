extends RefCounted
## Unit tests for AnimRouter's per-frame pose helpers: shortest-arc yaw
## stepping and the aim/travel facing pick. Split from test_anim_router.gd
## to stay under the lint cap on public methods per class.


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
