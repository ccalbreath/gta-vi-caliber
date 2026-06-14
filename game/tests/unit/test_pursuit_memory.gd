extends RefCounted
## Unit tests for PursuitMemory (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Pure chase-memory math — no scene.

const PLAYER := Vector3(20, 0, 5)
const LAST := Vector3(8, 0, -3)

# --- target ---------------------------------------------------------------


func test_target_is_live_when_seen() -> bool:
	return PursuitMemory.target(true, PLAYER, LAST) == PLAYER


func test_target_is_last_known_when_blind() -> bool:
	return PursuitMemory.target(false, PLAYER, LAST) == LAST


# --- should_give_up -------------------------------------------------------


func test_give_up_after_timeout() -> bool:
	return PursuitMemory.should_give_up(8.0, 8.0) and PursuitMemory.should_give_up(9.5, 8.0)


func test_no_give_up_before_timeout() -> bool:
	return not PursuitMemory.should_give_up(3.0, 8.0)


func test_zero_give_up_time_is_relentless() -> bool:
	return not PursuitMemory.should_give_up(999.0, 0.0)


# --- state ----------------------------------------------------------------


func test_state_pursue_when_seen() -> bool:
	# Seen overrides everything, even a long unseen timer.
	return PursuitMemory.state(true, 99.0, true, 8.0) == PursuitMemory.State.PURSUE


func test_state_lost_when_timed_out() -> bool:
	return PursuitMemory.state(false, 8.0, true, 8.0) == PursuitMemory.State.LOST


func test_state_search_when_reached_last_known() -> bool:
	return PursuitMemory.state(false, 2.0, true, 8.0) == PursuitMemory.State.SEARCH


func test_state_pursue_while_enroute_to_last_known() -> bool:
	return PursuitMemory.state(false, 2.0, false, 8.0) == PursuitMemory.State.PURSUE


# --- search_point ---------------------------------------------------------


func test_search_point_within_radius() -> bool:
	for i in range(0, 6):
		for j in range(0, 6):
			var p := PursuitMemory.search_point(LAST, float(i) / 5.0, float(j) / 5.0)
			var planar := Vector2(p.x - LAST.x, p.z - LAST.z)
			if planar.length() > PursuitMemory.SEARCH_RADIUS + 0.001:
				return false
	return true


func test_search_point_keeps_height() -> bool:
	var p := PursuitMemory.search_point(Vector3(4, 7, 2), 0.5, 0.5)
	return is_equal_approx(p.y, 7.0)


func test_search_point_custom_radius() -> bool:
	# u_radius 1.0 puts the point on the rim of the given radius.
	var p := PursuitMemory.search_point(LAST, 1.0, 0.0, 12.0)
	return is_equal_approx(Vector2(p.x - LAST.x, p.z - LAST.z).length(), 12.0)
