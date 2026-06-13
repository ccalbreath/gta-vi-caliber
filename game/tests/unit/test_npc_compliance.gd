extends RefCounted
## Unit tests for NpcCompliance (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers roster validation + trait clamping, the three channels (bribe with
## diminishing returns + wallet result, menace-scaled intimidation, charisma-scaled
## persuasion), durable-vs-decaying state, favour/silence gates, the progression/stars
## helpers, save round-trip, and the CrimeWitness silencing seam.


func test_default_npcs_loaded() -> bool:
	var nc := NpcCompliance.new()
	return nc.npc_count() == 4 and nc.has_npc("greedy_fixer") and nc.has_npc("scared_bystander")


func test_malformed_npcs_dropped() -> bool:
	var nc := (
		NpcCompliance
		. new(
			[
				{"id": "ok", "greed": 0.5},
				{"id": "", "greed": 0.5},  # empty id
				{"greed": 0.5},  # no id
				{"id": "ok", "greed": 0.9},  # duplicate id
			]
		)
	)
	return nc.npc_count() == 1 and nc.has_npc("ok")


func test_traits_clamped_on_register() -> bool:
	var nc := NpcCompliance.new()
	nc.register_npc("x", {"greed": 2.0, "fearfulness": -1.0, "stubbornness": 0.5})
	return (
		nc.greed_of("x") == 1.0 and nc.fearfulness_of("x") == 0.0 and nc.stubbornness_of("x") == 0.5
	)


func test_ids_sorted_deterministic() -> bool:
	var nc := NpcCompliance.new([{"id": "zed"}, {"id": "alpha"}, {"id": "mid"}])
	return nc.ids() == ["alpha", "mid", "zed"]


func test_compliance_starts_at_start_constant() -> bool:
	var nc := NpcCompliance.new()
	nc.register_npc("fresh")
	return (
		is_equal_approx(nc.compliance_of("fresh"), NpcCompliance.COMPLIANCE_START)
		and nc.compliance_of("nope") == 0.0
	)


func test_bribe_raises_compliance_and_reports_balance() -> bool:
	var nc := NpcCompliance.new()
	var r := nc.bribe("greedy_fixer", 500, 1000)
	var delta: float = r["delta"]
	return r["success"] and r["cost"] == 500 and r["new_balance"] == 500 and delta > 0.0


func test_bribe_greedier_npc_gains_more() -> bool:
	var nc := NpcCompliance.new()
	var greedy := nc.bribe("greedy_fixer", 500, 1000)  # greed 0.9
	var thug := nc.bribe("hardened_thug", 500, 1000)  # greed 0.2
	var dg: float = greedy["delta"]
	var dt: float = thug["delta"]
	return dg > dt


func test_bribe_insufficient_funds_fails_unchanged() -> bool:
	var nc := NpcCompliance.new()
	var before := nc.compliance_of("greedy_fixer")
	var r := nc.bribe("greedy_fixer", 500, 100)
	return (
		r["success"] == false
		and r["cost"] == 0
		and r["new_balance"] == 100
		and "funds" in r["reason"]
		and is_equal_approx(nc.compliance_of("greedy_fixer"), before)
	)


func test_bribe_unknown_or_nonpositive_fails() -> bool:
	var nc := NpcCompliance.new()
	var unknown := nc.bribe("nope", 100, 1000)
	var zero := nc.bribe("greedy_fixer", 0, 1000)
	return (
		unknown["success"] == false
		and zero["success"] == false
		and zero["cost"] == 0
		and zero["new_balance"] == 1000
	)


func test_bribe_diminishing_returns() -> bool:
	var nc := NpcCompliance.new()
	var first := nc.bribe("greedy_fixer", 500, 100000)
	var second := nc.bribe("greedy_fixer", 500, 100000)
	var d1: float = first["delta"]
	var d2: float = second["delta"]
	return d1 > d2 and nc.compliance_of("greedy_fixer") <= 1.0


func test_intimidate_scales_with_menace() -> bool:
	var nc := NpcCompliance.new()
	var high := nc.intimidate("scared_bystander", 1.0, 1.0)
	nc.reset_npc("scared_bystander")
	var low := nc.intimidate("scared_bystander", 0.2, 0.0)
	var dh: float = high["delta"]
	var dl: float = low["delta"]
	return dh > dl


func test_intimidate_fearful_more_effective_than_stubborn() -> bool:
	var nc := NpcCompliance.new()
	var scared := nc.intimidate("scared_bystander", 1.0, 1.0)  # fearful
	var thug := nc.intimidate("hardened_thug", 1.0, 1.0)  # stubborn + fearless
	var ds: float = scared["delta"]
	var dt: float = thug["delta"]
	return ds > dt


func test_intimidate_zero_menace_no_effect() -> bool:
	var nc := NpcCompliance.new()
	var before := nc.compliance_of("scared_bystander")
	var r := nc.intimidate("scared_bystander", 0.0, 0.0)
	var delta: float = r["delta"]
	return (
		r["success"] == false
		and delta == 0.0
		and is_equal_approx(nc.compliance_of("scared_bystander"), before)
	)


func test_intimidation_decays_over_time() -> bool:
	var nc := NpcCompliance.new()
	nc.intimidate("scared_bystander", 1.0, 1.0)
	var after_intimidate := nc.compliance_of("scared_bystander")
	nc.decay(10.0)
	var after_decay := nc.compliance_of("scared_bystander")
	return after_decay < after_intimidate and after_decay >= 0.0


func test_persuade_does_not_decay() -> bool:
	var nc := NpcCompliance.new()
	nc.persuade("neutral_local", 0.9)
	var after_persuade := nc.compliance_of("neutral_local")
	nc.decay(10.0)
	return is_equal_approx(after_persuade, nc.compliance_of("neutral_local"))


func test_persuade_scales_with_charisma() -> bool:
	var nc := NpcCompliance.new()
	var high := nc.persuade("neutral_local", 0.9)
	nc.reset_npc("neutral_local")
	var low := nc.persuade("neutral_local", 0.1)
	var dh: float = high["delta"]
	var dl: float = low["delta"]
	return dh > dl


func test_charisma_from_progression_monotonic_clamped() -> bool:
	var mid := NpcCompliance.charisma_from_progression(25, 50)
	return (
		NpcCompliance.charisma_from_progression(0, 50) == 0.0
		and NpcCompliance.charisma_from_progression(50, 50) == 1.0
		and mid > 0.0
		and mid < 1.0
	)


func test_notoriety_from_stars_maps_zero_to_five() -> bool:
	var two := NpcCompliance.notoriety_from_stars(2)
	return (
		NpcCompliance.notoriety_from_stars(0) == 0.0
		and NpcCompliance.notoriety_from_stars(5) == 1.0
		and two > 0.0
		and two < 1.0
	)


func test_favour_gate() -> bool:
	var nc := NpcCompliance.new()
	var before := nc.will_grant_favour("greedy_fixer")
	nc.bribe("greedy_fixer", 1000, 100000)
	nc.bribe("greedy_fixer", 1000, 100000)
	return before == false and nc.will_grant_favour("greedy_fixer")


func test_silence_gate_stricter_than_favour() -> bool:
	var nc := NpcCompliance.new()
	nc.register_npc("t", {"greed": 0.5})
	nc.bribe("t", 1000, 100000)
	nc.bribe("t", 1000, 100000)  # compliance ~0.56: above favour, below silence
	return (
		nc.will_grant_favour("t")
		and not nc.will_silence_witness("t")
		and NpcCompliance.SILENCE_GATE > NpcCompliance.FAVOUR_GATE
	)


func test_compliance_clamped_0_1() -> bool:
	var nc := NpcCompliance.new()
	for _i in 20:
		nc.bribe("greedy_fixer", 1000, 1000000)
		nc.persuade("greedy_fixer", 1.0)
	var maxed := nc.compliance_of("greedy_fixer")
	nc.decay(10000.0)
	return maxed <= 1.0 and nc.compliance_of("greedy_fixer") >= 0.0


func test_serialize_restore_round_trip() -> bool:
	var nc := NpcCompliance.new()
	nc.bribe("greedy_fixer", 500, 100000)
	nc.intimidate("scared_bystander", 1.0, 1.0)
	nc.persuade("neutral_local", 0.7)
	var snap := nc.serialize()
	var fresh := NpcCompliance.new()
	fresh.restore(snap)
	return (
		is_equal_approx(fresh.compliance_of("greedy_fixer"), nc.compliance_of("greedy_fixer"))
		and is_equal_approx(
			fresh.compliance_of("scared_bystander"), nc.compliance_of("scared_bystander")
		)
		and is_equal_approx(fresh.compliance_of("neutral_local"), nc.compliance_of("neutral_local"))
	)


func test_restore_drops_unknown_and_clamps() -> bool:
	var nc := NpcCompliance.new()
	nc.restore(
		{"npcs": {"ghost": {"durable": 0.5}, "greedy_fixer": {"durable": 5.0, "pressure": -1.0}}}
	)
	return not nc.has_npc("ghost") and is_equal_approx(nc.compliance_of("greedy_fixer"), 1.0)


func test_reset_npc_returns_to_start() -> bool:
	var nc := NpcCompliance.new()
	nc.bribe("greedy_fixer", 1000, 100000)
	nc.reset_npc("greedy_fixer")
	return is_equal_approx(nc.compliance_of("greedy_fixer"), NpcCompliance.COMPLIANCE_START)


func test_witness_silence_composition() -> bool:
	# A terrified bystander intimidated past SILENCE_GATE keeps quiet — the seam a
	# CrimeWitness gate reads before counting a witness toward heat.
	var nc := NpcCompliance.new()
	nc.intimidate("scared_bystander", 1.0, 1.0)
	nc.intimidate("scared_bystander", 1.0, 1.0)
	nc.intimidate("scared_bystander", 1.0, 1.0)
	return nc.will_silence_witness("scared_bystander")
