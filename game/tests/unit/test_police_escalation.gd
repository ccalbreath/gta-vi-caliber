extends RefCounted
## Unit tests for PoliceEscalation (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Deterministic; no asserts, no RNG.


func test_zero_stars_empty_response() -> bool:
	return PoliceEscalation.response_units(0).is_empty()


func test_zero_stars_no_heavy_assets() -> bool:
	return (
		not PoliceEscalation.has_swat(0)
		and not PoliceEscalation.has_helicopter(0)
		and not PoliceEscalation.has_military(0)
	)


func test_zero_stars_zero_aggression() -> bool:
	return is_equal_approx(PoliceEscalation.aggression(0), 0.0)


func test_zero_stars_no_roadblock() -> bool:
	return is_equal_approx(PoliceEscalation.roadblock_chance(0), 0.0)


func test_zero_stars_weapon_tier_zero() -> bool:
	return PoliceEscalation.weapon_tier(0) == 0


func test_one_star_is_a_beat_cop() -> bool:
	var units := PoliceEscalation.response_units(1)
	return units.size() == 1 and units[0] == PoliceEscalation.BEAT_COP


func test_response_never_shrinks_with_stars() -> bool:
	for s in range(0, PoliceEscalation.MAX_STARS):
		if (
			PoliceEscalation.response_units(s + 1).size()
			< PoliceEscalation.response_units(s).size()
		):
			return false
	return true


func test_response_grows_across_band() -> bool:
	# Strictly larger at the ends, proving the ramp actually escalates.
	return PoliceEscalation.response_units(6).size() > PoliceEscalation.response_units(1).size()


func test_returned_array_is_a_copy() -> bool:
	var units := PoliceEscalation.response_units(3)
	units.append(999)
	return PoliceEscalation.response_units(3).size() == 4


func test_swat_threshold_flips_at_three() -> bool:
	return not PoliceEscalation.has_swat(2) and PoliceEscalation.has_swat(3)


func test_swat_stays_true_above_threshold() -> bool:
	return (
		PoliceEscalation.has_swat(3)
		and PoliceEscalation.has_swat(4)
		and PoliceEscalation.has_swat(6)
	)


func test_helicopter_threshold_flips_at_four() -> bool:
	return not PoliceEscalation.has_helicopter(3) and PoliceEscalation.has_helicopter(4)


func test_helicopter_stays_true_above_threshold() -> bool:
	return PoliceEscalation.has_helicopter(4) and PoliceEscalation.has_helicopter(6)


func test_military_only_at_six() -> bool:
	return not PoliceEscalation.has_military(5) and PoliceEscalation.has_military(6)


func test_aggression_monotonic_in_unit_range() -> bool:
	for s in range(0, PoliceEscalation.MAX_STARS):
		var lo := PoliceEscalation.aggression(s)
		var hi := PoliceEscalation.aggression(s + 1)
		if hi < lo or lo < 0.0 or hi > 1.0:
			return false
	return true


func test_aggression_peaks_at_one() -> bool:
	return is_equal_approx(PoliceEscalation.aggression(6), 1.0)


func test_roadblock_chance_monotonic_and_bounded() -> bool:
	for s in range(0, PoliceEscalation.MAX_STARS):
		var lo := PoliceEscalation.roadblock_chance(s)
		var hi := PoliceEscalation.roadblock_chance(s + 1)
		if hi < lo or lo < 0.0 or hi > 1.0:
			return false
	return true


func test_reinforcement_interval_non_increasing_and_positive() -> bool:
	for s in range(0, PoliceEscalation.MAX_STARS):
		var lo := PoliceEscalation.reinforcement_interval(s)
		var hi := PoliceEscalation.reinforcement_interval(s + 1)
		if hi > lo or hi <= 0.0:
			return false
	return true


func test_weapon_tier_non_decreasing() -> bool:
	for s in range(0, PoliceEscalation.MAX_STARS):
		if PoliceEscalation.weapon_tier(s + 1) < PoliceEscalation.weapon_tier(s):
			return false
	return true


func test_weapon_tier_tops_out_at_military() -> bool:
	return PoliceEscalation.weapon_tier(6) == 4 and PoliceEscalation.weapon_tier(0) == 0


func test_high_stars_clamp_to_six() -> bool:
	return (
		PoliceEscalation.response_units(7).size() == PoliceEscalation.response_units(6).size()
		and PoliceEscalation.has_military(7)
		and is_equal_approx(PoliceEscalation.aggression(7), PoliceEscalation.aggression(6))
		and PoliceEscalation.weapon_tier(7) == PoliceEscalation.weapon_tier(6)
	)


func test_negative_stars_clamp_to_zero() -> bool:
	return (
		PoliceEscalation.response_units(-1).is_empty()
		and not PoliceEscalation.has_swat(-1)
		and is_equal_approx(PoliceEscalation.aggression(-1), 0.0)
		and PoliceEscalation.weapon_tier(-1) == 0
	)
