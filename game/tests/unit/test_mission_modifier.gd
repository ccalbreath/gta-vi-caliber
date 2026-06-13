extends RefCounted
## Unit tests for MissionModifier (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers catalogue validation, the active set (activate/deactivate/clear), the
## deterministic seeded roll, combined difficulty + payout multiplier, payout
## application, and the save round-trip.


func test_default_modifiers_loaded() -> bool:
	var mm := MissionModifier.new()
	return mm.modifier_count() == 5 and mm.has_modifier("no_damage")


func test_malformed_dropped() -> bool:
	var mm := (
		MissionModifier
		. new(
			[
				{"id": "ok", "payout_mult": 1.2},
				{"id": "", "payout_mult": 1.2},  # empty id
				{"payout_mult": 1.2},  # no id
				{"id": "cheap", "payout_mult": 0.9},  # payout < 1.0
				{"id": "ok", "payout_mult": 1.5},  # duplicate
			]
		)
	)
	return mm.modifier_count() == 1 and mm.has_modifier("ok")


func test_lookups() -> bool:
	var mm := MissionModifier.new()
	return (
		mm.difficulty_of("no_damage") == 0.6
		and mm.payout_mult_of("no_damage") == 1.5
		and mm.difficulty_of("nope") == 0.0
		and mm.payout_mult_of("nope") == 1.0
	)


func test_starts_with_no_active() -> bool:
	var mm := MissionModifier.new()
	return (
		mm.active_count() == 0
		and mm.combined_difficulty() == 0.0
		and mm.combined_payout_mult() == 1.0
	)


func test_activate_and_is_active() -> bool:
	var mm := MissionModifier.new()
	var ok := mm.activate("no_damage")
	return (
		ok and mm.is_active("no_damage") and mm.active_count() == 1 and not mm.activate("no_damage")
	)


func test_activate_unknown_fails() -> bool:
	var mm := MissionModifier.new()
	return not mm.activate("nope") and mm.active_count() == 0


func test_deactivate() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")
	var removed := mm.deactivate("no_damage")
	return removed and not mm.is_active("no_damage") and not mm.deactivate("no_damage")


func test_combined_difficulty_sums() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")  # 0.6
	mm.activate("time_limit")  # 0.3
	return is_equal_approx(mm.combined_difficulty(), 0.9)


func test_combined_payout_multiplies() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")  # 1.5
	mm.activate("time_limit")  # 1.25
	return is_equal_approx(mm.combined_payout_mult(), 1.5 * 1.25)


func test_apply_to_payout() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")  # 1.5
	return mm.apply_to_payout(10000) == 15000


func test_apply_to_payout_no_active_is_base() -> bool:
	var mm := MissionModifier.new()
	return mm.apply_to_payout(10000) == 10000


func test_roll_activates_count() -> bool:
	var mm := MissionModifier.new()
	var rolled := mm.roll(42, 2)
	return rolled.size() == 2 and mm.active_count() == 2


func test_roll_deterministic() -> bool:
	var mm := MissionModifier.new()
	var a := mm.roll(42, 3)
	var b := mm.roll(42, 3)
	return a == b


func test_roll_replaces_active_set() -> bool:
	var mm := MissionModifier.new()
	for id: String in mm.ids():
		mm.activate(id)  # all 5 active
	mm.roll(42, 2)
	return mm.active_count() == 2  # roll cleared the prior 5


func test_roll_count_capped_at_pool() -> bool:
	var mm := MissionModifier.new()
	var rolled := mm.roll(42, 99)  # only 5 modifiers exist
	return rolled.size() == 5 and mm.active_count() == 5


func test_roll_zero_count_empty() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")
	var rolled := mm.roll(42, 0)
	return rolled.size() == 0 and mm.active_count() == 0


func test_clear_active() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")
	mm.activate("time_limit")
	mm.clear_active()
	return mm.active_count() == 0


func test_serialize_restore_roundtrip() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")
	mm.activate("stay_undetected")
	var snap := mm.serialize()
	var fresh := MissionModifier.new()
	fresh.restore(snap)
	return (
		fresh.active_ids() == mm.active_ids()
		and is_equal_approx(fresh.combined_payout_mult(), mm.combined_payout_mult())
	)


func test_restore_drops_unknown() -> bool:
	var mm := MissionModifier.new()
	mm.restore({"active": ["no_damage", "ghost_modifier", "time_limit"]})
	return (
		mm.is_active("no_damage")
		and mm.is_active("time_limit")
		and not mm.is_active("ghost_modifier")
		and mm.active_count() == 2
	)


func test_restore_malformed_clears() -> bool:
	var mm := MissionModifier.new()
	mm.activate("no_damage")
	mm.restore({"active": 42})  # non-array
	return mm.active_count() == 0


func test_roll_seed_actually_affects_selection() -> bool:
	# Guards against a dead RNG: distinct seeds must be able to pick distinct sets
	# (test_roll_deterministic alone would pass even if the seed were ignored).
	var mm := MissionModifier.new()
	var first := mm.roll(0, 2)
	for s in range(1, 20):
		if mm.roll(s, 2) != first:
			return true
	return false


func test_roll_single_pick_and_negative_seed() -> bool:
	var mm := MissionModifier.new()
	var one := mm.roll(7, 1)
	var neg_a := mm.roll(-7, 2)
	var neg_b := mm.roll(-7, 2)
	# Exactly one pick; a negative seed is still valid + deterministic.
	return one.size() == 1 and neg_a == neg_b


func test_more_modifiers_raise_difficulty_and_payout() -> bool:
	var mm := MissionModifier.new()
	mm.activate("reverse_route")  # difficulty 0.2, payout 1.15
	var low := mm.apply_to_payout(10000)
	mm.activate("stay_undetected")  # difficulty 0.7, payout 1.6
	var high := mm.apply_to_payout(10000)
	return mm.combined_difficulty() > 0.2 and high > low
