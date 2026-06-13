extends RefCounted
## Unit tests for ProtagonistBond (runner contract: test_* methods return true).
##
## Covers the neutral start, init clamping, each event's direction, bounds
## clamping, tier thresholds, the backup gate, payout + switch-cooldown scalars,
## drift toward neutral (no overshoot), and a save round-trip.


func test_starts_neutral_partners() -> bool:
	var b := ProtagonistBond.new()
	return absf(b.bond() - 50.0) < 0.0001 and b.tier() == "partners"


func test_init_clamps() -> bool:
	return ProtagonistBond.new(200.0).bond() == 100.0 and ProtagonistBond.new(-5.0).bond() == 0.0


func test_coop_raises_bond() -> bool:
	var b := ProtagonistBond.new()
	var v := b.record_coop(1.0)  # +12 -> 62
	return absf(v - 62.0) < 0.0001 and absf(b.bond() - 62.0) < 0.0001


func test_rescue_raises_most() -> bool:
	var b := ProtagonistBond.new()
	b.record_rescue(1.0)  # +18 -> 68
	return absf(b.bond() - 68.0) < 0.0001


func test_conflict_lowers_bond() -> bool:
	var b := ProtagonistBond.new()
	b.record_conflict(1.0)  # -10 -> 40
	return absf(b.bond() - 40.0) < 0.0001 and b.tier() == "wary"


func test_betrayal_lowers_hard() -> bool:
	var b := ProtagonistBond.new()
	b.record_betrayal(1.0)  # -35 -> 15
	return absf(b.bond() - 15.0) < 0.0001 and b.tier() == "estranged"


func test_bounds_clamp() -> bool:
	var lo := ProtagonistBond.new()
	lo.record_betrayal(2.0)  # -70 -> clamps at 0
	var hi := ProtagonistBond.new()
	hi.record_coop(10.0)  # +120 -> clamps at 100
	return lo.bond() == 0.0 and hi.bond() == 100.0


func test_tiers() -> bool:
	return (
		ProtagonistBond.new(10.0).tier() == "estranged"
		and ProtagonistBond.new(30.0).tier() == "wary"
		and ProtagonistBond.new(60.0).tier() == "partners"
		and ProtagonistBond.new(85.0).tier() == "ride_or_die"
	)


func test_backup_gate() -> bool:
	var below := ProtagonistBond.new(50.0)  # < 55 threshold
	var above := ProtagonistBond.new(50.0)
	above.record_coop(1.0)  # -> 62, >= 55
	return below.backup_available() == false and above.backup_available() == true


func test_payout_multiplier_scales() -> bool:
	return (
		absf(ProtagonistBond.new(50.0).payout_multiplier() - 1.05) < 0.0001
		and absf(ProtagonistBond.new(100.0).payout_multiplier() - 1.30) < 0.0001
		and absf(ProtagonistBond.new(0.0).payout_multiplier() - 0.80) < 0.0001
	)


func test_switch_cooldown_scales() -> bool:
	return (
		absf(ProtagonistBond.new(0.0).switch_cooldown_scale() - 1.6) < 0.0001
		and absf(ProtagonistBond.new(100.0).switch_cooldown_scale() - 0.6) < 0.0001
		and absf(ProtagonistBond.new(50.0).switch_cooldown_scale() - 1.1) < 0.0001
	)


func test_drift_toward_neutral_no_overshoot() -> bool:
	var high := ProtagonistBond.new(80.0)
	high.drift(1.0)  # 80 - 1.5 -> 78.5
	var low := ProtagonistBond.new(20.0)
	low.drift(1.0)  # 20 + 1.5 -> 21.5
	var near := ProtagonistBond.new(50.5)
	near.drift(1.0)  # would step to 49.0 but clamps at the 50 baseline
	return (
		absf(high.bond() - 78.5) < 0.0001
		and absf(low.bond() - 21.5) < 0.0001
		and absf(near.bond() - 50.0) < 0.0001
	)


func test_save_round_trip() -> bool:
	var a := ProtagonistBond.new()
	a.record_rescue(1.0)
	a.record_conflict(0.5)
	var b := ProtagonistBond.new()
	b.from_dict(a.to_dict())
	return absf(b.bond() - a.bond()) < 0.0001 and b.tier() == a.tier()
