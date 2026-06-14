extends RefCounted
## Unit tests for ContrabandMarket (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## District multipliers come from Godot's hash(), which we don't hardcode; instead
## price assertions are derived from the model's own multiplier_for()/base_price so
## they stay deterministic and engine-correct.


func test_default_goods_loaded() -> bool:
	var m := ContrabandMarket.new()
	return m.goods_count() == 4 and m.has_good("jewelry")


func test_base_price_known() -> bool:
	var m := ContrabandMarket.new([{"id": "product", "base_price": 1500}])
	return m.base_price("product") == 1500


func test_base_price_unknown() -> bool:
	var m := ContrabandMarket.new()
	return m.base_price("nuke") == -1


func test_malformed_goods_dropped() -> bool:
	var m := (
		ContrabandMarket
		. new(
			[
				{"id": "ok", "base_price": 200},
				{"id": "", "base_price": 50},
				{"id": "free", "base_price": 0},
				{"id": "neg", "base_price": -10},
				{"base_price": 100},
			]
		)
	)
	return m.goods_count() == 1 and m.base_price("ok") == 200


func test_price_in_matches_multiplier() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var expected: int = int(round(1000.0 * m.multiplier_for("downtown")))
	return m.price_in("g", "downtown") == expected


func test_price_in_varies_by_district() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var a: int = m.price_in("g", "downtown")
	var b: int = m.price_in("g", "docks")
	return a != b


func test_price_in_unknown_good() -> bool:
	var m := ContrabandMarket.new()
	return m.price_in("nuke", "downtown") == -1


func test_multiplier_within_band() -> bool:
	var m := ContrabandMarket.new()
	var mult: float = m.multiplier_for("little_havana")
	return mult >= ContrabandMarket.MULTIPLIER_MIN and mult <= ContrabandMarket.MULTIPLIER_MAX


func test_buy_deducts_district_price() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 500}])
	var unit: int = m.price_in("g", "beach")
	var result: Dictionary = m.buy("g", 3, "beach", 100000)
	return (
		result["success"]
		and result["cost"] == unit * 3
		and result["new_balance"] == 100000 - unit * 3
	)


func test_buy_fails_unknown_zero_and_broke() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 500}])
	var unknown: Dictionary = m.buy("nuke", 1, "beach", 100000)
	var zero: Dictionary = m.buy("g", 0, "beach", 100000)
	var broke: Dictionary = m.buy("g", 100, "beach", 10)
	return (
		not unknown["success"]
		and unknown["new_balance"] == 100000
		and not zero["success"]
		and zero["cost"] == 0
		and not broke["success"]
		and broke["new_balance"] == 10
	)


func test_sell_revenue() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 500}])
	var unit: int = m.price_in("g", "docks")
	return m.sell("g", 4, "docks") == unit * 4


func test_sell_unknown_or_zero_is_zero() -> bool:
	var m := ContrabandMarket.new()
	return m.sell("nuke", 5, "docks") == 0 and m.sell("jewelry", 0, "docks") == 0


func test_best_market_picks_highest() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var districts: Array = ["downtown", "beach", "docks", "little_havana"]
	var winner: String = m.best_market("g", districts)
	var winner_price: int = m.price_in("g", winner)
	var ok: bool = true
	for d: Variant in districts:
		if m.price_in("g", str(d)) > winner_price:
			ok = false
	return ok and not winner.is_empty()


func test_best_market_single_unknown_and_empty() -> bool:
	var m := ContrabandMarket.new()
	return (
		m.best_market("jewelry", ["solo"]) == "solo"
		and m.best_market("nuke", ["a"]) == ""
		and m.best_market("jewelry", []) == ""
	)


func test_profit_positive_for_good_arbitrage() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var districts: Array = ["downtown", "beach", "docks", "little_havana"]
	var high: String = m.best_market("g", districts)
	# Find the cheapest district to buy from.
	var low: String = high
	var low_price: int = m.price_in("g", high)
	for d: Variant in districts:
		var p: int = m.price_in("g", str(d))
		if p < low_price:
			low_price = p
			low = str(d)
	return m.profit("g", low, high, 5) > 0


func test_profit_negative_for_bad_route() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var districts: Array = ["downtown", "beach", "docks", "little_havana"]
	var high: String = m.best_market("g", districts)
	var low: String = high
	var low_price: int = m.price_in("g", high)
	for d: Variant in districts:
		var p: int = m.price_in("g", str(d))
		if p < low_price:
			low_price = p
			low = str(d)
	# Buy high, sell low — the reverse of a good route — must lose money.
	return m.profit("g", high, low, 5) < 0


func test_profit_unknown_or_zero() -> bool:
	var m := ContrabandMarket.new()
	return m.profit("nuke", "a", "b", 5) == 0 and m.profit("jewelry", "a", "b", 0) == 0


func test_carry_accumulates_and_rejects_garbage() -> bool:
	var m := ContrabandMarket.new()
	m.carry("jewelry", 3)
	m.carry("jewelry", 2)
	m.carry("jewelry", -4)
	m.carry("nuke", 10)
	return m.carried("jewelry") == 5 and m.carried("nuke") == 0


func test_drop_never_negative() -> bool:
	var m := ContrabandMarket.new()
	m.carry("product", 2)
	m.drop("product", 10)
	return m.carried("product") == 0


func test_total_carried() -> bool:
	var m := ContrabandMarket.new()
	m.carry("jewelry", 3)
	m.carry("product", 4)
	return m.total_carried() == 7


func test_bust_risk_rises_with_load_and_clamps() -> bool:
	var m := ContrabandMarket.new()
	var light: float = m.bust_risk(2, 0.1)
	var heavy: float = m.bust_risk(8, 0.1)
	var rises := heavy > light and is_equal_approx(light, 0.2)
	# Clamped to 0..1 at the extremes.
	var clamped := (
		is_equal_approx(m.bust_risk(100, 0.5), 1.0) and is_equal_approx(m.bust_risk(0, -1.0), 0.0)
	)
	return rises and clamped


func test_fluctuate_deterministic_with_seed() -> bool:
	var a := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var b := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	# Seed both districts identically before drifting.
	a.price_in("g", "downtown")
	b.price_in("g", "downtown")
	a.fluctuate(ContrabandMarket.make_rng(42), 1.0)
	b.fluctuate(ContrabandMarket.make_rng(42), 1.0)
	return is_equal_approx(a.multiplier_for("downtown"), b.multiplier_for("downtown"))


func test_fluctuate_shifts_prices() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var before: float = m.multiplier_for("downtown")
	m.fluctuate(ContrabandMarket.make_rng(7), 1.0)
	var after: float = m.multiplier_for("downtown")
	return not is_equal_approx(before, after)


func test_fluctuate_null_rng_noop() -> bool:
	var m := ContrabandMarket.new([{"id": "g", "base_price": 1000}])
	var before: float = m.multiplier_for("downtown")
	m.fluctuate(null, 1.0)
	return is_equal_approx(m.multiplier_for("downtown"), before)
