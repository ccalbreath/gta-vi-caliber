extends RefCounted
## Unit tests for StatTracker (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_zero() -> bool:
	var s := StatTracker.new()
	return (
		is_equal_approx(s.get_stat("kills"), 0.0)
		and s.all_stats().is_empty()
		and is_equal_approx(s.completion_percent(), 0.0)
	)


func test_add_increments() -> bool:
	var s := StatTracker.new()
	s.add("kills", 3.0)
	return is_equal_approx(s.get_stat("kills"), 3.0)


func test_add_accumulates() -> bool:
	var s := StatTracker.new()
	s.add("kills", 3.0)
	s.add("kills", 4.0)
	return is_equal_approx(s.get_stat("kills"), 7.0)


func test_add_default_amount_is_one() -> bool:
	var s := StatTracker.new()
	s.add("headshots")
	s.add("headshots")
	return is_equal_approx(s.get_stat("headshots"), 2.0)


func test_negative_add_ignored() -> bool:
	var s := StatTracker.new()
	s.add("kills", 5.0)
	s.add("kills", -2.0)
	return is_equal_approx(s.get_stat("kills"), 5.0)


func test_unknown_stat_is_zero() -> bool:
	var s := StatTracker.new()
	return is_equal_approx(s.get_stat("never_set"), 0.0)


func test_set_stat_overrides() -> bool:
	var s := StatTracker.new()
	s.add("distance_m", 500.0)
	s.set_stat("distance_m", 42.0)
	return is_equal_approx(s.get_stat("distance_m"), 42.0)


func test_all_stats_is_a_copy() -> bool:
	var s := StatTracker.new()
	s.add("kills", 2.0)
	var snapshot := s.all_stats()
	snapshot["kills"] = 999.0
	return is_equal_approx(s.get_stat("kills"), 2.0)


func test_headshot_ratio_correct() -> bool:
	var s := StatTracker.new()
	s.add("kills", 10.0)
	s.add("headshots", 4.0)
	return is_equal_approx(s.headshot_ratio(), 0.4)


func test_headshot_ratio_zero_kills_safe() -> bool:
	var s := StatTracker.new()
	s.add("headshots", 3.0)
	return is_equal_approx(s.headshot_ratio(), 0.0)


func test_distance_km_conversion() -> bool:
	var s := StatTracker.new()
	s.add("distance_m", 2500.0)
	return is_equal_approx(s.distance_km(), 2.5)


func test_is_achieved_flips_at_threshold() -> bool:
	var s := StatTracker.new()
	s.add("kills", 99.0)
	var before := s.is_achieved("centurion")
	s.add("kills", 1.0)
	var after := s.is_achieved("centurion")
	return not before and after


func test_is_achieved_stays_after_threshold() -> bool:
	var s := StatTracker.new()
	s.add("kills", 250.0)
	return s.is_achieved("centurion")


func test_is_achieved_unknown_id() -> bool:
	var s := StatTracker.new()
	s.add("kills", 9999.0)
	return not s.is_achieved("no_such_achievement")


func test_achieved_list_grows() -> bool:
	var s := StatTracker.new()
	var empty := s.achieved_list().size()
	s.add("kills", 100.0)
	var one := s.achieved_list().size()
	s.add("headshots", 50.0)
	var two := s.achieved_list().size()
	return empty == 0 and one == 1 and two == 2


func test_completion_percent_partial() -> bool:
	var s := StatTracker.new()
	# 5 achievements total; earn 1 -> 20%.
	s.add("kills", 100.0)
	return is_equal_approx(s.completion_percent(), 20.0)


func test_completion_percent_full() -> bool:
	var s := StatTracker.new()
	s.add("kills", 100.0)
	s.add("headshots", 50.0)
	s.add("distance_m", 10000.0)
	s.add("missions_passed", 10.0)
	s.add("vehicles_jacked", 25.0)
	return is_equal_approx(s.completion_percent(), 100.0)


func test_completion_percent_bounds() -> bool:
	var s := StatTracker.new()
	var at_start := s.completion_percent()
	s.add("kills", 100.0)
	var mid := s.completion_percent()
	return at_start >= 0.0 and mid <= 100.0 and mid > at_start


func test_serialize_restore_round_trip() -> bool:
	var s := StatTracker.new()
	s.add("kills", 120.0)
	s.add("headshots", 55.0)
	s.add("distance_m", 3300.0)
	var snapshot := s.serialize()
	var loaded := StatTracker.new()
	loaded.restore(snapshot)
	return (
		is_equal_approx(loaded.get_stat("kills"), 120.0)
		and is_equal_approx(loaded.get_stat("headshots"), 55.0)
		and is_equal_approx(loaded.get_stat("distance_m"), 3300.0)
		and loaded.is_achieved("centurion")
		and loaded.is_achieved("sharpshooter")
	)


func test_restore_malformed_resets() -> bool:
	var s := StatTracker.new()
	s.add("kills", 80.0)
	s.restore({"stats": "not a dictionary"})
	return is_equal_approx(s.get_stat("kills"), 0.0)


func test_reset_zeroes() -> bool:
	var s := StatTracker.new()
	s.add("kills", 40.0)
	s.add("missions_passed", 5.0)
	s.reset()
	return s.all_stats().is_empty() and is_equal_approx(s.get_stat("kills"), 0.0)
