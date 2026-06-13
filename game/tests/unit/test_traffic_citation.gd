extends RefCounted
## Unit tests for TrafficCitation (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers zone validation, the three infraction types (speeding with grace + gross
## escalation, red-light, reckless/hit-and-run collision), cop-witness instant heat,
## the unpaid ledger + paying, tick() escalation, the WantedSystem civil->criminal
## seam, and save round-trip.


func test_default_zones_loaded() -> bool:
	var tc := TrafficCitation.new()
	return tc.zone_count() == 3 and tc.has_zone("residential")


func test_malformed_zones_dropped() -> bool:
	var tc := (
		TrafficCitation
		. new(
			[
				{"id": "ok", "limit_kmh": 50},
				{"id": "", "limit_kmh": 50},  # empty id
				{"limit_kmh": 50},  # no id
				{"id": "bad", "limit_kmh": -5},  # non-positive limit
				{"id": "ok", "limit_kmh": 99},  # duplicate id
			]
		)
	)
	return tc.zone_count() == 1 and tc.has_zone("ok")


func test_limit_lookup() -> bool:
	var tc := TrafficCitation.new()
	return tc.limit_of("highway") == 110 and tc.limit_of("nope") == -1


func test_speeding_under_grace_no_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_speeding("residential", 52.0)  # 52 < 50 + grace 10
	return r["success"] == false and r["fine"] == 0 and tc.unpaid_balance() == 0


func test_speeding_issues_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_speeding("residential", 80.0)  # over = 80 - 50 - 10 = 20
	var fine: int = r["fine"]
	var over: float = r["overage"]
	return (
		r["success"]
		and r["kind"] == "speeding"
		and is_equal_approx(over, 20.0)
		and fine == int(round(20.0 * 8.0))
		and tc.unpaid_balance() == fine
	)


func test_speeding_unknown_zone_fails() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_speeding("nope", 200.0)
	return r["success"] == false and "zone" in r["reason"] and tc.citation_count() == 0


func test_extreme_speed_flags_star() -> bool:
	var tc := TrafficCitation.new()
	# school limit 30; over = 95 - 30 - 10 = 55 >= SPEED_STAR_KMH (gross speeding)
	var r := tc.record_speeding("school", 95.0)
	var sev: float = r["star_severity"]
	return r["escalated"] == true and sev > 0.0


func test_red_light_run_issues_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0)
	return (
		r["success"]
		and r["kind"] == "red_light"
		and r["fine"] == TrafficCitation.REDLIGHT_FINE
		and tc.unpaid_balance() == TrafficCitation.REDLIGHT_FINE
	)


func test_green_light_no_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_red_light(TrafficCitation.Light.GREEN, 0.0, 40.0)
	return r["success"] == false and r["fine"] == 0 and tc.citation_count() == 0


func test_red_light_stopped_no_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_red_light(TrafficCitation.Light.RED, 5.0, 0.0)  # stopped at line
	return r["success"] == false


func test_collision_reckless_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_collision(40.0, false)
	var sev: float = r["star_severity"]
	return (
		r["kind"] == "reckless"
		and r["fine"] == int(round(TrafficCitation.RECKLESS_FINE_PER_HP * 40.0))
		and sev == 0.0
	)


func test_hit_and_run_multiplies_and_escalates() -> bool:
	var tc := TrafficCitation.new()
	var reckless := tc.record_collision(40.0, false)
	var hr := tc.record_collision(40.0, true)
	var hr_fine: int = hr["fine"]
	var reckless_fine: int = reckless["fine"]
	var sev: float = hr["star_severity"]
	return (
		hr["kind"] == "hit_and_run"
		and hr_fine == int(round(600.0 * TrafficCitation.HIT_AND_RUN_MULT))
		and hr_fine > reckless_fine
		and sev > 0.0
	)


func test_minor_collision_no_fine() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.record_collision(2.0, false)  # below RECKLESS_DAMAGE_MIN
	return r["success"] == false and tc.citation_count() == 0


func test_cop_witness_instant_star() -> bool:
	var tc := TrafficCitation.new()
	# over 20 < SPEED_STAR_KMH, but a watching cop promotes the quiet ticket to heat.
	var r := tc.record_speeding("residential", 80.0, true)
	var sev: float = r["star_severity"]
	return sev > 0.0


func test_consume_star_severity_accumulates_then_zeroes() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0, true)  # cop sees -> 0.5
	tc.record_collision(40.0, true)  # hit-and-run -> 0.7
	var pending := tc.pending_star_severity()
	var consumed := tc.consume_star_severity()
	var second := tc.consume_star_severity()
	return pending > 0.0 and is_equal_approx(consumed, pending) and second == 0.0


func test_unpaid_balance_accumulates() -> bool:
	var tc := TrafficCitation.new()
	var s1 := tc.record_speeding("residential", 80.0)
	var s2 := tc.record_speeding("highway", 160.0)
	var rl := tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0)
	var f1: int = s1["fine"]
	var f2: int = s2["fine"]
	var f3: int = rl["fine"]
	return tc.unpaid_balance() == f1 + f2 + f3 and tc.citation_count() == 3


func test_pay_all_success() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)
	var owed := tc.unpaid_balance()
	var r := tc.pay(owed + 100)
	return (
		r["success"]
		and r["cost"] == owed
		and r["new_balance"] == 100
		and tc.unpaid_balance() == 0
		and tc.total_paid() == owed
	)


func test_pay_insufficient_fails() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)
	var owed := tc.unpaid_balance()
	var r := tc.pay(owed - 1)
	return (
		r["success"] == false
		and r["new_balance"] == owed - 1
		and "insufficient" in r["reason"]
		and tc.citation_count() == 1
	)


func test_pay_nothing_outstanding_fails() -> bool:
	var tc := TrafficCitation.new()
	var r := tc.pay(1000)
	return r["success"] == false and r["new_balance"] == 1000 and tc.citation_count() == 0


func test_pay_single_citation() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)
	tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0)
	var before := tc.unpaid_balance()
	var first_id: String = tc.outstanding_ids()[0]
	var insufficient := tc.pay_citation(first_id, 1)  # fine > 1 -> fail, unchanged
	var unknown := tc.pay_citation("cit_999", 100000)
	var r := tc.pay_citation(first_id, 100000)
	var cost: int = r["cost"]
	return (
		insufficient["success"] == false
		and unknown["success"] == false
		and r["success"]
		and tc.citation_count() == 1
		and tc.unpaid_balance() == before - cost
	)


func test_load_dict_resets_next_id() -> bool:
	# A new citation issued after a load must not reuse (overwrite) a loaded id.
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)  # cit_0
	tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0)  # cit_1
	var fresh := TrafficCitation.new()
	fresh.load_dict(tc.to_dict())
	var count_before := fresh.citation_count()
	var balance_before := fresh.unpaid_balance()
	var r := fresh.record_speeding("residential", 80.0)
	var new_fine: int = r["fine"]
	return (
		fresh.citation_count() == count_before + 1
		and fresh.unpaid_balance() == balance_before + new_fine
	)


func test_tick_escalates_ignored_citation() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)
	var esc := tc.tick(TrafficCitation.ESCALATE_AFTER_DAYS + 1.0)
	var esc2 := tc.tick(1.0)  # already escalated -> not again
	var first: Dictionary = esc[0]
	var sev: float = first["star_severity"]
	# Escalation severity is returned (fed directly), NOT added to the witnessed accumulator.
	return esc.size() == 1 and sev > 0.0 and esc2.size() == 0 and tc.pending_star_severity() == 0.0


func test_tick_ignores_nonpositive_delta() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)  # quiet ticket, no heat
	var a := tc.tick(0.0)
	var b := tc.tick(-3.0)
	return a.size() == 0 and b.size() == 0 and tc.pending_star_severity() == 0.0


func test_to_dict_load_dict_roundtrip() -> bool:
	var tc := TrafficCitation.new()
	tc.record_speeding("residential", 80.0)
	tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0)
	tc.pay_citation(tc.outstanding_ids()[0], 100000)
	var snap := tc.to_dict()
	var fresh := TrafficCitation.new()
	fresh.load_dict(snap)
	return (
		fresh.unpaid_balance() == tc.unpaid_balance()
		and fresh.citation_count() == tc.citation_count()
		and fresh.total_issued() == tc.total_issued()
		and fresh.total_paid() == tc.total_paid()
	)


func test_wanted_composition_escalation() -> bool:
	# The civil->criminal seam: witnessed/serious infractions promote into WantedSystem.
	var tc := TrafficCitation.new()
	tc.record_collision(40.0, true)  # hit-and-run -> 0.7
	tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0, true)  # cop-witnessed -> 0.5
	var ws := WantedSystem.new()
	ws.add_crime(tc.consume_star_severity())  # heat 1.2 -> >= 1 star
	# A single quiet unpaid ticket alone never raises a star.
	var quiet := TrafficCitation.new()
	quiet.record_speeding("residential", 80.0)
	var ws2 := WantedSystem.new()
	ws2.add_crime(quiet.consume_star_severity())
	return ws.stars() >= 1 and ws2.stars() == 0
