extends RefCounted
## Unit tests for StreetRace (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).

const R: float = 5.0


func _square_track() -> Array:
	return [
		Vector3(0.0, 0.0, 0.0),
		Vector3(100.0, 0.0, 0.0),
		Vector3(100.0, 0.0, 100.0),
		Vector3(0.0, 0.0, 100.0),
	]


func test_starts_at_first_checkpoint() -> bool:
	var race := StreetRace.new(_square_track(), 2)
	return (
		race.checkpoint_index() == 0
		and race.current_lap() == 1
		and race.total_laps() == 2
		and not race.is_finished()
		and race.current_checkpoint() == Vector3(0.0, 0.0, 0.0)
	)


func test_reached_advances_within_radius() -> bool:
	var race := StreetRace.new(_square_track(), 1)
	var hit := race.reached(Vector3(2.0, 9.0, 1.0), R)
	return hit and race.checkpoint_index() == 1


func test_reached_ignores_y_height() -> bool:
	# 9 units up but on the gate in XZ -> still counts.
	var race := StreetRace.new(_square_track(), 1)
	return race.reached(Vector3(0.0, 50.0, 0.0), R)


func test_reached_not_outside_radius() -> bool:
	var race := StreetRace.new(_square_track(), 1)
	var hit := race.reached(Vector3(50.0, 0.0, 50.0), R)
	return not hit and race.checkpoint_index() == 0


func test_reached_wraps_into_next_lap() -> bool:
	var race := StreetRace.new(_square_track(), 2)
	# Clear all 4 checkpoints of lap 1.
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	race.reached(Vector3(100.0, 0.0, 0.0), R)
	race.reached(Vector3(100.0, 0.0, 100.0), R)
	race.reached(Vector3(0.0, 0.0, 100.0), R)
	return race.checkpoint_index() == 0 and race.current_lap() == 2 and not race.is_finished()


func test_finished_after_last_checkpoint_last_lap() -> bool:
	var race := StreetRace.new([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)], 1)
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	var done := race.reached(Vector3(10.0, 0.0, 0.0), R)
	return done and race.is_finished() and race.current_lap() == 1


func test_reached_noop_after_finish() -> bool:
	var race := StreetRace.new([Vector3(0.0, 0.0, 0.0)], 1)
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	return race.is_finished() and not race.reached(Vector3(0.0, 0.0, 0.0), R)


func test_empty_checkpoints_starts_finished() -> bool:
	var race := StreetRace.new([], 3)
	return (
		race.is_finished()
		and not race.reached(Vector3.ZERO, R)
		and is_equal_approx(race.progress(), 1.0)
		and race.checkpoints_remaining() == 0
	)


func test_progress_ramps_zero_to_one() -> bool:
	var race := StreetRace.new(_square_track(), 2)  # 8 gates total
	var start_ok := is_equal_approx(race.progress(), 0.0)
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	race.reached(Vector3(100.0, 0.0, 0.0), R)  # 2 of 8 done
	var mid_ok := is_equal_approx(race.progress(), 0.25)
	# Clear 4 more gates in ring order: rest of lap 1 (P2, P3) + first 2 of lap 2.
	race.reached(Vector3(100.0, 0.0, 100.0), R)  # P2
	race.reached(Vector3(0.0, 0.0, 100.0), R)  # P3 -> wraps into lap 2
	race.reached(Vector3(0.0, 0.0, 0.0), R)  # P0 of lap 2
	race.reached(Vector3(100.0, 0.0, 0.0), R)  # P1 of lap 2
	# 6 of 8 done after lap 1 (4) + 2 more.
	var late_ok := is_equal_approx(race.progress(), 0.75)
	return start_ok and mid_ok and late_ok


func test_progress_one_when_finished() -> bool:
	var race := StreetRace.new([Vector3(0.0, 0.0, 0.0)], 1)
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	return is_equal_approx(race.progress(), 1.0)


func test_checkpoints_remaining_counts_all_laps() -> bool:
	var race := StreetRace.new(_square_track(), 3)  # 12 total
	var start := race.checkpoints_remaining()
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	return start == 12 and race.checkpoints_remaining() == 11


func test_placement_orders_by_progress() -> bool:
	# Player at 0.5, rivals further/behind.
	var first := StreetRace.placement(0.9, [0.5, 0.2])
	var second := StreetRace.placement(0.5, [0.9, 0.2])
	var third := StreetRace.placement(0.1, [0.9, 0.5])
	return first == 1 and second == 2 and third == 3


func test_placement_ties_keep_player_ahead() -> bool:
	# Equal progress is not "strictly further along" -> player stays 1st.
	return StreetRace.placement(0.5, [0.5, 0.5]) == 1


func test_placement_no_rivals_is_first() -> bool:
	return StreetRace.placement(0.3, []) == 1


func test_gap_to_distance_behind() -> bool:
	# 0.2 of a 1000m loop behind -> 200m.
	var gap: float = StreetRace.gap_to(0.7, 0.5, 1000.0)
	return is_equal_approx(gap, 200.0)


func test_gap_to_floors_at_zero() -> bool:
	# Already ahead -> no positive gap; bad track length -> 0.
	var ahead: float = StreetRace.gap_to(0.3, 0.5, 1000.0)
	var bad: float = StreetRace.gap_to(0.7, 0.5, 0.0)
	return is_equal_approx(ahead, 0.0) and is_equal_approx(bad, 0.0)


func test_timing_accrues() -> bool:
	var race := StreetRace.new(_square_track(), 1)
	race.tick(1.5)
	race.tick(2.0)
	race.tick(-9.0)  # ignored
	return is_equal_approx(race.elapsed(), 3.5)


func test_lap_splits_and_best_lap() -> bool:
	var race := StreetRace.new(_square_track(), 2)
	# Lap 1: clock to 10s, then clear 4 gates.
	race.tick(10.0)
	for cp in _square_track():
		race.reached(cp as Vector3, R)
	var lap1_ok := is_equal_approx(race.last_lap(), 10.0)
	# Lap 2: 4 more seconds, then clear 4 gates -> faster lap.
	race.tick(4.0)
	for cp in _square_track():
		race.reached(cp as Vector3, R)
	var lap2_ok := is_equal_approx(race.last_lap(), 4.0)
	return lap1_ok and lap2_ok and is_equal_approx(race.best_lap(), 4.0)


func test_reset_clears_state() -> bool:
	var race := StreetRace.new(_square_track(), 2)
	race.tick(5.0)
	race.reached(Vector3(0.0, 0.0, 0.0), R)
	race.reset()
	return (
		race.checkpoint_index() == 0
		and race.current_lap() == 1
		and is_equal_approx(race.elapsed(), 0.0)
		and is_equal_approx(race.best_lap(), 0.0)
		and not race.is_finished()
	)


func test_reward_by_placement() -> bool:
	var first := StreetRace.reward(1, 1000)  # full
	var second := StreetRace.reward(2, 1000)  # 0.75
	var fourth := StreetRace.reward(4, 1000)  # 0.25
	var sixth := StreetRace.reward(6, 1000)  # floored 0.25
	return first == 1000 and second == 750 and fourth == 250 and sixth == 250


func test_reward_dnf_is_zero() -> bool:
	return StreetRace.reward(0, 1000) == 0 and StreetRace.reward(-1, 1000) == 0


func test_reward_zero_base() -> bool:
	return StreetRace.reward(1, 0) == 0
