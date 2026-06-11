extends RefCounted
## Unit tests for WantedLevel — the heat/stars gameplay rules.


func test_starts_unwanted() -> bool:
	var w := WantedLevel.new()
	return w.stars() == 0 and not w.is_wanted()


func test_small_heat_is_one_star() -> bool:
	var w := WantedLevel.new()
	w.add_heat(1.0)
	return w.stars() == 1 and w.is_wanted()


func test_heat_maps_to_higher_stars() -> bool:
	var w := WantedLevel.new()
	w.add_heat(10.0)
	return w.stars() == 4


func test_caps_at_five_stars() -> bool:
	var w := WantedLevel.new()
	w.add_heat(1000.0)
	return w.stars() == WantedLevel.MAX_STARS


func test_crime_kinds_add_heat() -> bool:
	var w := WantedLevel.new()
	w.add_crime("shooting")
	return w.stars() >= 2


func test_decay_reduces_stars() -> bool:
	var w := WantedLevel.new()
	w.add_heat(3.0)  # 2 stars
	var before := w.stars()
	for _i in 10:
		w.decay(1.0)  # 10 s * 0.5 = 5 heat removed → below 1 star
	return before == 2 and w.stars() == 0


func test_clear_resets() -> bool:
	var w := WantedLevel.new()
	w.add_heat(12.0)
	w.clear()
	return w.stars() == 0 and not w.is_wanted()
