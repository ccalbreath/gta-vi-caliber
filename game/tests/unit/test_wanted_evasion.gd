extends RefCounted
## Unit tests for WantedEvasion (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_visible_full_timer() -> bool:
	var e := WantedEvasion.new(12.0)
	return (
		e.is_visible()
		and e.state() == WantedEvasion.State.VISIBLE
		and is_equal_approx(e.time_left(), 12.0)
		and is_equal_approx(e.search_progress(), 0.0)
	)


func test_first_unseen_enters_searching() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 1.0)
	return e.is_searching() and not e.is_visible() and not e.is_cold()


func test_countdown_decrements_with_delta() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 2.0)
	return is_equal_approx(e.time_left(), 8.0)


func test_reaches_cold_after_full_duration() -> bool:
	var e := WantedEvasion.new(10.0)
	for _i in 5:
		e.update(false, 2.0)
	return e.is_cold() and is_equal_approx(e.time_left(), 0.0)


func test_cold_progress_is_one() -> bool:
	var e := WantedEvasion.new(10.0)
	for _i in 5:
		e.update(false, 2.0)
	return is_equal_approx(e.search_progress(), 1.0)


func test_resighting_resets_to_visible_and_refills() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 6.0)
	e.update(true, 0.0)
	return (
		e.is_visible()
		and is_equal_approx(e.time_left(), 10.0)
		and is_equal_approx(e.search_progress(), 0.0)
	)


func test_resighting_then_searching_starts_from_full() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 7.0)
	e.update(true, 0.0)
	e.update(false, 2.0)
	return e.is_searching() and is_equal_approx(e.time_left(), 8.0)


func test_notify_crime_forces_visible() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 5.0)
	e.notify_crime()
	return e.is_visible() and is_equal_approx(e.time_left(), 10.0)


func test_notify_crime_from_cold_reheats() -> bool:
	var e := WantedEvasion.new(10.0)
	for _i in 5:
		e.update(false, 2.0)
	e.notify_crime()
	return e.is_visible() and is_equal_approx(e.time_left(), 10.0)


func test_reset_forces_visible() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 4.0)
	e.reset()
	return e.is_visible() and is_equal_approx(e.time_left(), 10.0)


func test_progress_zero_while_visible() -> bool:
	var e := WantedEvasion.new(10.0)
	return is_equal_approx(e.search_progress(), 0.0)


func test_progress_ramps_during_search() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 5.0)
	return is_equal_approx(e.search_progress(), 0.5)


func test_progress_monotonic_within_search() -> bool:
	var e := WantedEvasion.new(10.0)
	var last := 0.0
	for _i in 4:
		e.update(false, 2.0)
		var p := e.search_progress()
		if p < last:
			return false
		last = p
	return is_equal_approx(last, 0.8)


func test_time_left_clamped_low() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 100.0)
	return e.is_cold() and is_equal_approx(e.time_left(), 0.0)


func test_time_left_clamped_high() -> bool:
	# A re-sight refill never exceeds the duration.
	var e := WantedEvasion.new(10.0)
	e.update(true, 5.0)
	return is_equal_approx(e.time_left(), 10.0)


func test_is_cold_only_at_end() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 9.0)
	var not_yet := not e.is_cold()
	e.update(false, 1.0)
	return not_yet and e.is_cold()


func test_cold_stays_cold_until_reset() -> bool:
	var e := WantedEvasion.new(10.0)
	for _i in 5:
		e.update(false, 2.0)
	e.update(false, 2.0)
	e.update(false, 2.0)
	return e.is_cold() and is_equal_approx(e.time_left(), 0.0)


func test_zero_and_negative_delta_safe() -> bool:
	var e := WantedEvasion.new(10.0)
	e.update(false, 3.0)
	e.update(false, 0.0)
	e.update(false, -5.0)
	return e.is_searching() and is_equal_approx(e.time_left(), 7.0)


func test_default_duration_is_twelve() -> bool:
	var e := WantedEvasion.new()
	return is_equal_approx(e.search_duration, 12.0) and is_equal_approx(e.time_left(), 12.0)
