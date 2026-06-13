extends RefCounted
## Unit tests for CrimeNotoriety (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers the rap sheet: category validation, infamy accrual + clamp, tier
## escalation, dominant-category + label, weighted notoriety/fear/hiring/price
## scalars, news-severity mapping, daily decay (orthogonal to heat), save round-trip,
## and the documented NewsBulletin/ShopModel composition seams.


func test_default_categories_loaded() -> bool:
	var cn := CrimeNotoriety.new()
	return (
		cn.category_count() == 7 and cn.has_category("cop_killing") and cn.has_category("bank_job")
	)


func test_malformed_rows_dropped() -> bool:
	var cn := (
		CrimeNotoriety
		. new(
			[
				{"id": "ok", "fear_weight": 1.0},
				{"id": ""},  # empty id
				{"fear_weight": 2.0},  # no id
				{"id": "ok"},  # duplicate id
			]
		)
	)
	return cn.category_count() == 1 and cn.has_category("ok")


func test_default_infamy_zero_and_clean() -> bool:
	var cn := CrimeNotoriety.new()
	return (
		cn.infamy_of("arson") == 0.0
		and cn.tier_of("arson") == "minor"
		and cn.is_clean()
		and cn.reputation_label() == ""
	)


func test_unknown_category_is_inert() -> bool:
	var cn := CrimeNotoriety.new()
	var count := cn.category_count()
	return (
		cn.infamy_of("nope") == 0.0
		and cn.tier_of("nope") == ""
		and cn.record("nope", 5.0) == -1.0
		and cn.category_count() == count
	)


func test_record_accumulates_and_returns() -> bool:
	var cn := CrimeNotoriety.new()
	var a := cn.record("bank_job", 4.0)
	var b := cn.record("bank_job", 3.0)
	var c := cn.record("bank_job", -9.0)  # negative ignored
	return a == 4.0 and b == 7.0 and c == 7.0 and cn.infamy_of("bank_job") == 7.0


func test_infamy_clamps_to_max() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 99999.0)
	return cn.infamy_of("cop_killing") == CrimeNotoriety.MAX_INFAMY


func test_tier_thresholds_escalate() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 10.0)
	var minor := cn.tier_of("cop_killing")
	cn.record("cop_killing", 20.0)  # 30
	var known := cn.tier_of("cop_killing")
	cn.record("cop_killing", 30.0)  # 60
	var notorious := cn.tier_of("cop_killing")
	cn.record("cop_killing", 30.0)  # 90
	var legendary := cn.tier_of("cop_killing")
	return (
		minor == "minor"
		and known == "known"
		and notorious == "notorious"
		and legendary == "legendary"
	)


func test_dominant_category_and_label() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 80.0)
	cn.record("assault", 10.0)
	var clean := CrimeNotoriety.new()
	return (
		cn.dominant_category() == "cop_killing"
		and "Cop-Killer" in cn.reputation_label()
		and clean.dominant_category() == ""
		and clean.reputation_label() == ""
	)


func test_dominant_tie_break_deterministic() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 20.0)
	cn.record("arson", 20.0)
	# Equal infamy: ids() is sorted, so 'arson' wins over 'cop_killing'.
	return cn.dominant_category() == "arson"


func test_notoriety_score_weighted() -> bool:
	var a := CrimeNotoriety.new()
	a.record("cop_killing", 10.0)  # fear_weight 1.5
	var b := CrimeNotoriety.new()
	b.record("assault", 10.0)  # fear_weight 0.5
	return a.notoriety_score() > b.notoriety_score()


func test_fear_level_and_intimidates() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 100.0)
	cn.record("arson", 100.0)
	var clean := CrimeNotoriety.new()
	return (
		cn.fear_level() <= 1.0
		and cn.fear_level() > 0.9
		and cn.intimidates_civilians()
		and clean.fear_level() == 0.0
		and not clean.intimidates_civilians()
	)


func test_hiring_appeal_is_theft_weighted() -> bool:
	var theft := CrimeNotoriety.new()
	theft.record("bank_job", 50.0)  # hire_weight 1.5
	var brawl := CrimeNotoriety.new()
	brawl.record("assault", 50.0)  # hire_weight 0.4
	return (
		theft.hiring_appeal() > brawl.hiring_appeal()
		and theft.hiring_appeal() <= 1.0
		and theft.hiring_appeal() >= 0.0
	)


func test_shop_price_multiplier_scales_with_fear() -> bool:
	var clean := CrimeNotoriety.new()
	var feared := CrimeNotoriety.new()
	feared.record("cop_killing", 100.0)
	return (
		clean.shop_price_multiplier() == 1.0
		and feared.shop_price_multiplier() > 1.0
		and feared.shop_price_multiplier() <= CrimeNotoriety.PRICE_MAX_MULT
	)


func test_news_severity_maps_1_to_5() -> bool:
	var cn := CrimeNotoriety.new()
	var low := cn.news_severity_for("bank_job")  # infamy 0
	cn.record("bank_job", 100.0)
	var high := cn.news_severity_for("bank_job")
	var unknown := cn.news_severity_for("nope")
	return low == 1 and high == 5 and unknown == 1


func test_decay_fades_but_does_not_zero_quickly() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("assault", 10.0)  # decay_per_day 0.8
	cn.decay(1.0)
	var after_one := cn.infamy_of("assault")
	cn.decay(0.0)
	cn.decay(-3.0)
	var noop := cn.infamy_of("assault")
	cn.decay(1000.0)  # never below 0
	var floored := cn.infamy_of("assault")
	return is_equal_approx(after_one, 9.2) and is_equal_approx(noop, 9.2) and floored == 0.0


func test_decay_is_orthogonal_to_heat() -> bool:
	# Unlike wanted heat (which decays to 0 per tick), infamy persists across days.
	var cn := CrimeNotoriety.new()
	cn.record("bank_job", 40.0)  # decay_per_day 0.4
	for _i in 10:
		cn.decay(1.0)
	return cn.infamy_of("bank_job") > 0.0 and not cn.is_clean()


func test_serialize_restore_round_trips() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 30.0)
	cn.record("bank_job", 50.0)
	cn.record("arson", 15.0)
	var snap := cn.serialize()
	var fresh := CrimeNotoriety.new()
	fresh.restore(snap)
	var infamy_dict: Dictionary = snap["infamy"]
	var keys: Array = infamy_dict.keys()
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	return (
		fresh.infamy_of("cop_killing") == 30.0
		and fresh.infamy_of("bank_job") == 50.0
		and fresh.infamy_of("arson") == 15.0
		and is_equal_approx(fresh.notoriety_score(), cn.notoriety_score())
		and keys == sorted_keys
	)


func test_restore_drops_unknown_and_clamps() -> bool:
	var cn := CrimeNotoriety.new()
	cn.restore({"infamy": {"cop_killing": 5.0, "ghost_crime": 9.0, "bank_job": 1000000000.0}})
	var ok: bool = (
		cn.infamy_of("cop_killing") == 5.0
		and not cn.has_category("ghost_crime")
		and cn.infamy_of("bank_job") == CrimeNotoriety.MAX_INFAMY
	)
	var malformed := CrimeNotoriety.new()
	malformed.record("arson", 10.0)
	malformed.restore({"infamy": "garbage"})  # non-dict -> clean
	return ok and malformed.is_clean()


func test_reset_wipes_sheet() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("cop_killing", 50.0)
	cn.record("bank_job", 30.0)
	cn.reset()
	return (
		cn.is_clean()
		and cn.notoriety_score() == 0.0
		and cn.dominant_category() == ""
		and cn.shop_price_multiplier() == 1.0
	)


func test_fear_curve_is_violence_weighted() -> bool:
	# Intentional curve: a maxed violent-ish crime (bank robbery) intimidates civilians,
	# but a maxed low-menace crime (car theft) does not — even at full infamy.
	var robber := CrimeNotoriety.new()
	robber.record("bank_job", 100.0)
	var thief := CrimeNotoriety.new()
	thief.record("grand_theft_auto", 100.0)
	return (
		robber.intimidates_civilians()
		and not thief.intimidates_civilians()
		and thief.dominant_category() == "grand_theft_auto"
	)  # still your signature crime


func test_composition_news_and_shop_seam() -> bool:
	var cn := CrimeNotoriety.new()
	cn.record("bank_job", 70.0)
	var sev := cn.news_severity_for(cn.dominant_category())  # passable to NewsBulletin.report()
	var mult := cn.shop_price_multiplier()  # passable into a ShopModel price calc
	return sev >= 1 and sev <= 5 and mult > 0.0
