extends RefCounted
## Unit tests for ProtectionRacket (see tests/run_tests.gd for the runner contract: test_*
## methods return true to pass).
##
## Covers the roster + malformed drops, shaking a front down (protect + intimidate, take the
## max), the compliant→defiant transition as fear decays, tribute accrual + collection, the
## daily-income aggregate, ctor, and the save round-trip.


func test_default_fronts_loaded() -> bool:
	var pr := ProtectionRacket.new()
	return pr.front_count() == 4 and pr.has_front("liquor_store") and pr.protected_count() == 0


func test_malformed_dropped() -> bool:
	var pr := (
		ProtectionRacket
		. new(
			[
				{"id": "ok", "tribute_per_day": 100},
				{"id": "", "tribute_per_day": 100},  # empty id
				{"id": "no_tribute"},  # missing tribute
				{"id": "zero", "tribute_per_day": 0},  # non-positive
				{"id": "ok", "tribute_per_day": 200},  # duplicate
			]
		)
	)
	return pr.front_count() == 1 and pr.has_front("ok")


func test_starts_unprotected() -> bool:
	var pr := ProtectionRacket.new()
	return (
		not pr.is_protected("liquor_store")
		and pr.intimidation_of("liquor_store") == 0.0
		and not pr.is_compliant("liquor_store")
		and not pr.is_defiant("liquor_store")
		and pr.daily_income() == 0
	)


func test_shake_down_protects_and_intimidates() -> bool:
	var pr := ProtectionRacket.new()
	var level := pr.shake_down("liquor_store", 0.8)
	return (
		is_equal_approx(level, 0.8)
		and pr.is_protected("liquor_store")
		and pr.is_compliant("liquor_store")
	)


func test_shake_down_only_raises() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("liquor_store", 0.8)
	var lower := pr.shake_down("liquor_store", 0.5)  # can't scare them LESS
	return is_equal_approx(lower, 0.8)


func test_shake_down_unknown_returns_negative() -> bool:
	var pr := ProtectionRacket.new()
	return pr.shake_down("nope", 0.5) == -1.0 and not pr.is_protected("nope")


func test_accrue_compliant_pays() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("liquor_store", 1.0)
	pr.accrue(2.0)  # 300/day * 2
	return pr.pending_tribute() == 600


func test_accrue_decays_intimidation() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("liquor_store", 1.0)
	pr.accrue(3.0)  # 1.0 - 0.1*3
	return is_equal_approx(pr.intimidation_of("liquor_store"), 0.7)


func test_decays_to_defiance_and_stops_paying() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("liquor_store", 0.5)
	pr.accrue(1.0)  # pay, intim 0.4
	pr.accrue(1.0)  # pay, intim 0.3
	pr.accrue(1.0)  # pay (>=0.3), intim ~0.2 -> defiant
	var compliant_pending := pr.pending_tribute()  # 900
	var defiant := pr.is_defiant("liquor_store")
	pr.accrue(1.0)  # below the line -> NO pay
	return compliant_pending == 900 and defiant and pr.pending_tribute() == 900


func test_collect_banks_and_zeroes() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("nightclub", 1.0)
	pr.accrue(2.0)  # 800/day * 2
	var banked := pr.collect()
	return banked == 1600 and pr.pending_tribute() == 0


func test_daily_income_only_compliant() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("liquor_store", 1.0)
	var with_one := pr.daily_income()  # 300
	for _i in 9:
		pr.accrue(1.0)  # 1.0 - 0.1*9 = 0.1 -> defiant
	return with_one == 300 and pr.daily_income() == 0


func test_protected_count() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("liquor_store", 0.5)
	pr.shake_down("diner", 0.5)
	return pr.protected_count() == 2


func test_save_round_trip() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("pawn_shop", 0.9)
	pr.accrue(2.0)
	var clone := ProtectionRacket.new()
	clone.from_dict(pr.to_dict())
	return (
		clone.is_protected("pawn_shop")
		and is_equal_approx(clone.intimidation_of("pawn_shop"), pr.intimidation_of("pawn_shop"))
		and clone.pending_tribute() == pr.pending_tribute()
	)


func test_from_dict_rejects_non_dict() -> bool:
	var pr := ProtectionRacket.new()
	pr.shake_down("diner", 0.7)
	pr.from_dict("not a dict")
	return pr.is_protected("diner")
