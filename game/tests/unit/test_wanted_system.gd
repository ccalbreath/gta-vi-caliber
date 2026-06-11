extends RefCounted
## Unit tests for WantedSystem (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_clean() -> bool:
	var w := WantedSystem.new()
	return is_equal_approx(w.heat, 0.0) and w.stars() == 0 and not w.is_wanted()


func test_crime_raises_heat_and_stars() -> bool:
	var w := WantedSystem.new()
	w.add_crime(3.5)
	return w.is_wanted() and w.stars() == 2


func test_negative_crime_ignored() -> bool:
	var w := WantedSystem.new()
	w.add_crime(-5.0)
	return is_equal_approx(w.heat, 0.0)


func test_heat_capped() -> bool:
	var w := WantedSystem.new(0.4, 8.0)
	w.add_crime(100.0)
	return is_equal_approx(w.heat, 8.0)


func test_decay_when_not_committing() -> bool:
	var w := WantedSystem.new(1.0, 20.0)
	w.add_crime(5.0)
	w.tick(2.0, false)
	return is_equal_approx(w.heat, 3.0)


func test_no_decay_while_committing() -> bool:
	var w := WantedSystem.new(1.0, 20.0)
	w.add_crime(5.0)
	w.tick(2.0, true)
	return is_equal_approx(w.heat, 5.0)


func test_heat_floors_at_zero() -> bool:
	var w := WantedSystem.new(1.0, 20.0)
	w.add_crime(1.0)
	w.tick(10.0, false)
	return is_equal_approx(w.heat, 0.0) and not w.is_wanted()


func test_stars_for_thresholds() -> bool:
	return (
		WantedSystem.stars_for(0.5) == 0
		and WantedSystem.stars_for(1.0) == 1
		and WantedSystem.stars_for(3.0) == 2
		and WantedSystem.stars_for(6.0) == 3
		and WantedSystem.stars_for(10.0) == 4
		and WantedSystem.stars_for(16.0) == 5
	)


func test_stars_capped_at_five() -> bool:
	return WantedSystem.stars_for(999.0) == 5


func test_response_units_scale_with_stars() -> bool:
	return WantedSystem.response_units(0) == 0 and WantedSystem.response_units(3) == 3


func test_response_units_clamped() -> bool:
	return WantedSystem.response_units(9) == 5
