extends RefCounted
## Unit tests for PursuitTactics (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Pure police-pursuit math: lead intercept,
## ram/PIT/block authorisation, closing speed, and disengage logic.

# --- intercept_point ---------------------------------------------------------


func test_intercept_leads_ahead_of_moving_target() -> bool:
	# Target at x=10 fleeing +X at 5; faster pursuer at origin must aim past it.
	var aim := PursuitTactics.intercept_point(
		Vector3(10, 0, 0), Vector3(5, 0, 0), Vector3.ZERO, 10.0
	)
	# Closed-form solution gives t=2 → x = 10 + 5*2 = 20.
	return is_equal_approx(aim.x, 20.0) and is_equal_approx(aim.z, 0.0)


func test_intercept_aim_is_beyond_current_pos() -> bool:
	# Generic check: lead point is further along travel than the target is now.
	var aim := PursuitTactics.intercept_point(
		Vector3(0, 0, 20), Vector3(0, 0, 8), Vector3.ZERO, 14.0
	)
	return aim.z > 20.0


func test_intercept_stationary_falls_back_to_pos() -> bool:
	var aim := PursuitTactics.intercept_point(Vector3(7, 0, -3), Vector3.ZERO, Vector3.ZERO, 12.0)
	return aim.is_equal_approx(Vector3(7, 0, -3))


func test_intercept_zero_pursuer_speed_falls_back() -> bool:
	var aim := PursuitTactics.intercept_point(Vector3(5, 0, 5), Vector3(3, 0, 0), Vector3.ZERO, 0.0)
	return aim.is_equal_approx(Vector3(5, 0, 5))


func test_intercept_unreachable_slow_pursuer_falls_back() -> bool:
	# Target flees directly away faster than the pursuer can travel: no positive
	# intercept time → fall back to current position.
	var aim := PursuitTactics.intercept_point(
		Vector3(10, 0, 0), Vector3(20, 0, 0), Vector3.ZERO, 5.0
	)
	return aim.is_equal_approx(Vector3(10, 0, 0))


func test_intercept_equal_speed_linear_case() -> bool:
	# a≈0 (target speed == pursuer speed) exercises the linear branch; target
	# crossing perpendicular still yields a finite lead point.
	var aim := PursuitTactics.intercept_point(
		Vector3(0, 0, 10), Vector3(6, 0, 0), Vector3.ZERO, 6.0
	)
	# Linear solve: t = -c/b = -100 / (2*(0)) ... here b = 2*(to.dot(tv)).
	# to=(0,0,10)-... = (0,0,10); tv=(6,0,0); dot=0 → b=0 → no solution → fallback.
	return aim.is_equal_approx(Vector3(0, 0, 10))


# --- should_ram --------------------------------------------------------------


func test_ram_true_when_close_aligned_and_high_stars() -> bool:
	# Pursuer heading +X, target just ahead, 4 stars.
	return PursuitTactics.should_ram(Vector3.ZERO, Vector3(1, 0, 0), Vector3(4, 0, 0), 8.0, 4)


func test_ram_false_at_low_stars_even_when_close() -> bool:
	return not PursuitTactics.should_ram(Vector3.ZERO, Vector3(1, 0, 0), Vector3(4, 0, 0), 8.0, 2)


func test_ram_false_when_out_of_range() -> bool:
	return not PursuitTactics.should_ram(Vector3.ZERO, Vector3(1, 0, 0), Vector3(20, 0, 0), 8.0, 5)


func test_ram_false_when_target_off_to_the_side() -> bool:
	# Target dead abeam (90° off heading) is outside the ram cone.
	return not PursuitTactics.should_ram(Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 0, 4), 8.0, 5)


func test_ram_at_exactly_threshold_stars() -> bool:
	return PursuitTactics.should_ram(Vector3.ZERO, Vector3(1, 0, 0), Vector3(3, 0, 0), 8.0, 3)


# --- block_offset ------------------------------------------------------------


func test_block_offset_is_ahead_and_picks_side() -> bool:
	# Target moving +X: block point sits ahead (+X) and offset to the requested
	# side — right (+1) is -Z, left (-1) is +Z.
	var right := PursuitTactics.block_offset(Vector3.ZERO, Vector3(5, 0, 0), 1.0, 10.0)
	var left := PursuitTactics.block_offset(Vector3.ZERO, Vector3(5, 0, 0), -1.0, 10.0)
	return right.x > 0.0 and right.z < 0.0 and left.z > 0.0


func test_block_offset_stationary_steps_to_side() -> bool:
	var b := PursuitTactics.block_offset(Vector3(2, 0, 2), Vector3.ZERO, 1.0, 6.0)
	return b.is_equal_approx(Vector3(2, 0, 8))


# --- pit_side ----------------------------------------------------------------


func test_pit_side_right_when_pursuer_on_right() -> bool:
	# Target moving +X; pursuer at -Z is on the target's right → +1.
	var s := PursuitTactics.pit_side(Vector3(0, 0, -3), Vector3.ZERO, Vector3(5, 0, 0))
	return s > 0.0


func test_pit_side_left_when_pursuer_on_left() -> bool:
	# Pursuer at +Z is on the target's left → -1.
	var s := PursuitTactics.pit_side(Vector3(0, 0, 3), Vector3.ZERO, Vector3(5, 0, 0))
	return s < 0.0


func test_pit_side_defaults_when_target_still() -> bool:
	return is_equal_approx(
		PursuitTactics.pit_side(Vector3(1, 0, 1), Vector3.ZERO, Vector3.ZERO), 1.0
	)


# --- desired_speed -----------------------------------------------------------


func test_desired_speed_rises_with_distance_and_caps() -> bool:
	var near := PursuitTactics.desired_speed(15.0, 20.0, 40.0)
	var far := PursuitTactics.desired_speed(35.0, 20.0, 40.0)
	var capped := PursuitTactics.desired_speed(200.0, 20.0, 40.0)
	return far > near and is_equal_approx(capped, 40.0)


func test_desired_speed_eases_off_when_right_behind() -> bool:
	# Right on the bumper the pursuer should drop below base speed to not overshoot.
	var bumper := PursuitTactics.desired_speed(1.0, 20.0, 40.0)
	return bumper < 20.0


# --- should_back_off ---------------------------------------------------------


func test_back_off_true_at_zero_stars() -> bool:
	return PursuitTactics.should_back_off(0, 10.0)


func test_back_off_true_when_target_far() -> bool:
	return PursuitTactics.should_back_off(4, 200.0)


func test_back_off_false_while_engaged() -> bool:
	return not PursuitTactics.should_back_off(3, 30.0)


# --- choose_tactic -----------------------------------------------------------


func test_choose_back_off_when_cleared() -> bool:
	return (
		PursuitTactics.choose_tactic(
			Vector3.ZERO, Vector3(1, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, 0), 0, 8.0
		)
		== PursuitTactics.Tactic.BACK_OFF
	)


func test_choose_ram_when_lined_up_and_authorised() -> bool:
	return (
		PursuitTactics.choose_tactic(
			Vector3.ZERO, Vector3(1, 0, 0), Vector3(4, 0, 0), Vector3(5, 0, 0), 4, 8.0
		)
		== PursuitTactics.Tactic.RAM
	)


func test_choose_chase_at_low_stars() -> bool:
	# 1 star, target dead ahead and close: no aggression authorised → plain chase.
	return (
		PursuitTactics.choose_tactic(
			Vector3.ZERO, Vector3(1, 0, 0), Vector3(4, 0, 0), Vector3(5, 0, 0), 1, 8.0
		)
		== PursuitTactics.Tactic.CHASE
	)


func test_choose_pit_when_alongside_and_authorised() -> bool:
	# 4 stars; pursuer abeam the target (off to the side) → PIT, not ram.
	return (
		PursuitTactics.choose_tactic(
			Vector3(0, 0, -5), Vector3(1, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, 0), 4, 8.0
		)
		== PursuitTactics.Tactic.PIT
	)
