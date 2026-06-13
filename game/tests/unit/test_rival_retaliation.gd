extends RefCounted
## Unit tests for RivalRetaliation (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers faction validation, grudge provoke/pacify + clamp, the revenge threshold,
## escalating strike kinds + severity, grudge decay, cooldown-gated retaliation via
## tick(), the save round-trip, and GangTerritory alignment.


func test_default_factions_loaded() -> bool:
	var rr := RivalRetaliation.new()
	return rr.faction_count() == 3 and rr.has_faction("vice_kings")


func test_malformed_dropped() -> bool:
	var rr := RivalRetaliation.new([{"id": "ok"}, {"id": ""}, {"decay_per_day": 1.0}, {"id": "ok"}])
	return rr.faction_count() == 1 and rr.has_faction("ok")


func test_starts_calm() -> bool:
	var rr := RivalRetaliation.new()
	return (
		rr.grudge_of("vice_kings") == 0.0
		and not rr.is_seeking_revenge("vice_kings")
		and rr.retaliation_kind_for("vice_kings") == ""
	)


func test_unknown_faction_inert() -> bool:
	var rr := RivalRetaliation.new()
	return (
		rr.grudge_of("nope") == 0.0
		and rr.provoke("nope", 50.0) == -1.0
		and rr.pacify("nope", 10.0) == -1.0
		and not rr.is_seeking_revenge("nope")
	)


func test_provoke_raises_grudge() -> bool:
	var rr := RivalRetaliation.new()
	var g := rr.provoke("vice_kings", 30.0)
	return (
		g == 30.0 and rr.grudge_of("vice_kings") == 30.0 and rr.provoke("vice_kings", -10.0) == 30.0
	)


func test_grudge_clamps_to_max() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 99999.0)
	return rr.grudge_of("vice_kings") == RivalRetaliation.MAX_GRUDGE


func test_seeking_revenge_threshold() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 39.0)
	var below := rr.is_seeking_revenge("vice_kings")
	rr.provoke("vice_kings", 5.0)  # 44 >= RETALIATE_AT
	return not below and rr.is_seeking_revenge("vice_kings")


func test_pacify_reduces_grudge() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 50.0)
	var g := rr.pacify("vice_kings", 20.0)
	return g == 30.0 and not rr.is_seeking_revenge("vice_kings")


func test_retaliation_kind_escalates() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 45.0)
	var vandal := rr.retaliation_kind_for("vice_kings")
	rr.provoke("vice_kings", 20.0)  # 65
	var raid := rr.retaliation_kind_for("vice_kings")
	rr.provoke("vice_kings", 20.0)  # 85
	var hit := rr.retaliation_kind_for("vice_kings")
	return vandal == "vandalism" and raid == "property_raid" and hit == "hit_squad"


func test_severity_scales_with_grudge() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 100.0)
	return (
		is_equal_approx(rr.retaliation_severity("vice_kings"), 1.0)
		and rr.retaliation_severity("marina_cartel") == 0.0
	)


func test_tick_decays_grudge() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 30.0)  # below threshold
	rr.tick(2.0)  # decay 2 * 3 = 6 -> 24
	return is_equal_approx(rr.grudge_of("vice_kings"), 24.0)


func test_tick_retaliates_after_cooldown() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 70.0)
	var strikes := rr.tick(3.0)  # cooldown 2-3<=0, grudge 70-9=61 -> property_raid
	var first: Dictionary = strikes[0]
	return (
		strikes.size() == 1
		and first["faction_id"] == "vice_kings"
		and first["kind"] == "property_raid"
	)


func test_tick_no_retaliation_below_threshold() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 30.0)
	var strikes := rr.tick(3.0)  # grudge decays to 21 < 40
	return strikes.size() == 0


func test_tick_respects_cooldown_between_strikes() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 100.0)
	var s1 := rr.tick(3.0)  # strike (cooldown 2-3<=0), reset cooldown 2; grudge 91
	var s2 := rr.tick(1.0)  # cooldown 2-1=1 > 0 -> no strike; grudge 88
	var s3 := rr.tick(2.0)  # cooldown 1-2<=0 -> strike; grudge 82
	return s1.size() == 1 and s2.size() == 0 and s3.size() == 1


func test_tick_nonpositive_noop() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 70.0)
	var a := rr.tick(0.0)
	var b := rr.tick(-3.0)
	return a.size() == 0 and b.size() == 0 and is_equal_approx(rr.grudge_of("vice_kings"), 70.0)


func test_decay_floors_at_zero() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 10.0)
	rr.tick(100.0)  # huge decay
	return rr.grudge_of("vice_kings") == 0.0


func test_independent_faction_grudges() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 80.0)
	rr.provoke("marina_cartel", 20.0)
	return rr.is_seeking_revenge("vice_kings") and not rr.is_seeking_revenge("marina_cartel")


func test_serialize_restore_roundtrip() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 65.0)
	rr.tick(1.0)  # grudge 62, cooldown 1
	var snap := rr.serialize()
	var fresh := RivalRetaliation.new()
	fresh.restore(snap)
	return (
		is_equal_approx(fresh.grudge_of("vice_kings"), rr.grudge_of("vice_kings"))
		and fresh.retaliation_kind_for("vice_kings") == rr.retaliation_kind_for("vice_kings")
	)


func test_restore_drops_unknown_and_clamps() -> bool:
	var rr := RivalRetaliation.new()
	rr.restore(
		{
			"factions":
			{"ghost": {"grudge": 50.0}, "vice_kings": {"grudge": 9999.0, "cooldown": -5.0}}
		}
	)
	return not rr.has_faction("ghost") and rr.grudge_of("vice_kings") == RivalRetaliation.MAX_GRUDGE


func test_restore_malformed_noop() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 50.0)
	var before := rr.grudge_of("vice_kings")
	rr.restore({"factions": 42})  # non-dict
	rr.restore({})  # missing key
	return is_equal_approx(rr.grudge_of("vice_kings"), before)


func test_reset_calms_all() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 80.0)
	rr.provoke("marina_cartel", 50.0)
	rr.reset()
	return rr.grudge_of("vice_kings") == 0.0 and not rr.is_seeking_revenge("marina_cartel")


func test_retaliation_kind_at_exact_boundaries() -> bool:
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 40.0)  # exactly RETALIATE_AT
	var at_retaliate := rr.retaliation_kind_for("vice_kings")
	rr.provoke("vice_kings", 20.0)  # exactly 60 (RAID_AT)
	var at_raid := rr.retaliation_kind_for("vice_kings")
	rr.provoke("vice_kings", 20.0)  # exactly 80 (HIT_SQUAD_AT)
	var at_hit := rr.retaliation_kind_for("vice_kings")
	return at_retaliate == "vandalism" and at_raid == "property_raid" and at_hit == "hit_squad"


func test_restore_midcooldown_no_spurious_strike() -> bool:
	# After a strike resets the cooldown, a save/load must NOT let it strike again early.
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 100.0)
	rr.tick(3.0)  # strikes; cooldown reset to 2.0
	var fresh := RivalRetaliation.new()
	fresh.restore(rr.serialize())
	var strikes := fresh.tick(1.0)  # cooldown 2-1=1 > 0 -> no spurious strike
	return strikes.size() == 0 and fresh.is_seeking_revenge("vice_kings")


func test_large_timeskip_still_strikes_once() -> bool:
	# A long time-skip that fully decays the grudge still triggers the one strike it
	# earned (enraged at the start of the span) — no avoidance by skipping time.
	var rr := RivalRetaliation.new()
	rr.provoke("vice_kings", 100.0)
	var strikes := rr.tick(40.0)  # decay 120 -> grudge 0, but enraged at span start
	return strikes.size() == 1 and rr.grudge_of("vice_kings") == 0.0


func test_composition_aligns_with_gang_territory() -> bool:
	# Faction ids line up with GangTerritory's gang owners.
	var rr := RivalRetaliation.new()
	var gt := GangTerritory.new()
	return rr.has_faction(gt.owner_of("downtown"))
