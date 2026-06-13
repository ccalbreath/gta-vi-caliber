extends RefCounted
## Cap / edge-case unit tests for NpcCompliance (split from test_npc_compliance.gd to
## stay under the 25-public-method lint cap; same runner contract).
##
## Covers the disposition caps that keep the cost curve honest — bribe over-pay +
## maxed-NPC reporting, the intimidation pressure ceiling (a hardened thug can't be
## scared silent), the persuasion cap (talking earns favours, never silence) — plus
## the guard/no-op branches and the menace blend weighting.


func test_bribe_overpay_saturates_gain_but_charges_full() -> bool:
	var nc := NpcCompliance.new()
	var big := nc.bribe("greedy_fixer", 5000, 100000)  # 5x the full-effect amount
	nc.reset_npc("greedy_fixer")
	var exact := nc.bribe("greedy_fixer", 1000, 100000)
	var d_big: float = big["delta"]
	var d_exact: float = exact["delta"]
	# Over-paying buys nothing extra but still costs the full amount.
	return big["cost"] == 5000 and big["new_balance"] == 95000 and is_equal_approx(d_big, d_exact)


func test_bribe_maxed_npc_fails_reports_compliance() -> bool:
	var nc := NpcCompliance.new()
	for _i in 30:
		nc.bribe("greedy_fixer", 1000, 10000000)
	var r := nc.bribe("greedy_fixer", 1000, 10000000)
	# A maxed NPC's failed bribe must report compliance ~1.0, not 0.0.
	return (
		r["success"] == false
		and is_equal_approx(r["compliance"], 1.0)
		and r["cost"] == 0
		and "compliant" in r["reason"]
	)


func test_bribe_failure_reports_actual_compliance() -> bool:
	var nc := NpcCompliance.new()
	var r := nc.bribe("greedy_fixer", 5000, 100)  # insufficient funds
	return (
		r["success"] == false and is_equal_approx(r["compliance"], NpcCompliance.COMPLIANCE_START)
	)


func test_intimidate_stubborn_npc_wont_budge() -> bool:
	var nc := NpcCompliance.new()
	nc.intimidate("hardened_thug", 1.0, 1.0)
	nc.intimidate("hardened_thug", 1.0, 1.0)  # already at the disposition ceiling
	var r := nc.intimidate("hardened_thug", 1.0, 1.0)
	var menace: float = r["menace"]
	return r["success"] == false and r["delta"] == 0.0 and "budge" in r["reason"] and menace > 0.0


func test_hardened_thug_resists_intimidation() -> bool:
	# A fearless, stubborn NPC can never be silenced by intimidation alone.
	var nc := NpcCompliance.new()
	for _i in 50:
		nc.intimidate("hardened_thug", 1.0, 1.0)
	return (
		not nc.will_silence_witness("hardened_thug")
		and nc.compliance_of("hardened_thug") < NpcCompliance.SILENCE_GATE
	)


func test_persuade_unknown_id_fails() -> bool:
	var nc := NpcCompliance.new()
	var r := nc.persuade("nope", 0.9)
	return r["success"] == false and r["delta"] == 0.0 and "unknown" in r["reason"]


func test_persuade_zero_charisma_fails() -> bool:
	var nc := NpcCompliance.new()
	var r := nc.persuade("neutral_local", 0.0)
	return r["success"] == false and r["delta"] == 0.0


func test_persuade_alone_cannot_silence() -> bool:
	# Talking earns favours but never a witness's silence — caps below SILENCE_GATE.
	var nc := NpcCompliance.new()
	for _i in 30:
		nc.persuade("neutral_local", 1.0)
	return (
		not nc.will_silence_witness("neutral_local")
		and nc.will_grant_favour("neutral_local")
		and nc.compliance_of("neutral_local") <= NpcCompliance.PERSUADE_CAP + 0.0001
	)


func test_register_npc_rejects_empty_and_duplicate() -> bool:
	var nc := NpcCompliance.new()
	var empty := nc.register_npc("")
	nc.register_npc("dup", {"greed": 0.2})
	var dup := nc.register_npc("dup", {"greed": 0.9})  # second profile ignored
	return empty == false and dup == false and is_equal_approx(nc.greed_of("dup"), 0.2)


func test_restore_malformed_is_noop() -> bool:
	var nc := NpcCompliance.new()
	nc.bribe("greedy_fixer", 500, 100000)
	var before := nc.compliance_of("greedy_fixer")
	nc.restore({"npcs": 42})  # non-dict npcs
	nc.restore({})  # missing npcs
	return is_equal_approx(nc.compliance_of("greedy_fixer"), before) and nc.npc_count() == 4


func test_decay_nonpositive_is_noop() -> bool:
	var nc := NpcCompliance.new()
	nc.intimidate("scared_bystander", 1.0, 1.0)
	var after_intim := nc.compliance_of("scared_bystander")
	nc.decay(0.0)
	nc.decay(-5.0)
	return is_equal_approx(nc.compliance_of("scared_bystander"), after_intim)


func test_menace_weights_notoriety_over_weapon() -> bool:
	var nc := NpcCompliance.new()
	var n_only: float = nc.intimidate("scared_bystander", 1.0, 0.0)["menace"]
	nc.reset_npc("scared_bystander")
	var w_only: float = nc.intimidate("scared_bystander", 0.0, 1.0)["menace"]
	return is_equal_approx(n_only, 0.6) and is_equal_approx(w_only, 0.4)
