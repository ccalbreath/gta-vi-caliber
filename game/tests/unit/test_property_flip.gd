extends RefCounted
## Unit tests for PropertyFlip (see tests/run_tests.gd for the runner contract: test_* methods
## return true to pass).
##
## Covers the roster + malformed/free-property drops, the buy → renovate → sell lifecycle and its
## ordering guards (can't renovate before buying, can't sell before renovating, can't re-buy a sold
## property), the appreciation profit, and the save round-trip.


func test_default_roster_loaded() -> bool:
	var f := PropertyFlip.new()
	return (
		f.count() == 4
		and f.has_property("harbor_loft")
		and f.state_of("harbor_loft") == PropertyFlip.STATE_AVAILABLE
	)


func test_dud_lot_loses_money() -> bool:
	# The roster includes a money-loser so flipping is a real decision, not free profit.
	var f := PropertyFlip.new()
	return f.has_property("swamp_shack") and f.profit_of("swamp_shack") < 0


func test_malformed_and_free_dropped() -> bool:
	var f := (
		PropertyFlip
		. new(
			[
				{"id": "ok", "price": 100, "reno_cost": 50, "resale": 300},
				{"id": "", "price": 100, "reno_cost": 50, "resale": 300},  # empty id
				{"price": 100, "reno_cost": 50, "resale": 300},  # missing id
				{"id": "free", "price": 0, "reno_cost": 50, "resale": 300},  # free buy
				{"id": "noreno", "price": 100, "reno_cost": 0, "resale": 300},  # no work
				{"id": "ok", "price": 999, "reno_cost": 1, "resale": 9},  # duplicate
			]
		)
	)
	return f.count() == 1 and f.has_property("ok")


func test_flip_lifecycle() -> bool:
	var f := PropertyFlip.new()
	var expected_resale := f.resale_of("harbor_loft")  # capture before the sale
	var bought := f.buy("harbor_loft")
	var owned := f.state_of("harbor_loft") == PropertyFlip.STATE_OWNED
	var renovated := f.renovate("harbor_loft")
	var proceeds := f.sell("harbor_loft")
	return (
		bought
		and owned
		and renovated
		and proceeds == expected_resale
		and expected_resale > 0
		and f.is_sold("harbor_loft")
	)


func test_cannot_renovate_before_buying() -> bool:
	var f := PropertyFlip.new()
	var ok := f.renovate("harbor_loft")  # still available
	return not ok and f.state_of("harbor_loft") == PropertyFlip.STATE_AVAILABLE


func test_cannot_sell_before_renovating() -> bool:
	var f := PropertyFlip.new()
	f.buy("harbor_loft")
	var proceeds := f.sell("harbor_loft")  # owned, not renovated
	return proceeds == 0 and f.state_of("harbor_loft") == PropertyFlip.STATE_OWNED


func test_cannot_rebuy_sold() -> bool:
	var f := PropertyFlip.new()
	f.buy("harbor_loft")
	f.renovate("harbor_loft")
	f.sell("harbor_loft")
	var rebought := f.buy("harbor_loft")  # terminal
	return not rebought and f.is_sold("harbor_loft")


func test_profit_is_resale_minus_costs() -> bool:
	var f := PropertyFlip.new()
	var costs := f.price_of("harbor_loft") + f.reno_cost_of("harbor_loft")
	var expected := f.resale_of("harbor_loft") - costs
	return f.profit_of("harbor_loft") == expected and expected > 0


func test_save_round_trip() -> bool:
	var f := PropertyFlip.new()
	f.buy("harbor_loft")
	f.renovate("harbor_loft")
	var clone := PropertyFlip.new()
	clone.from_dict(f.to_dict())
	return clone.state_of("harbor_loft") == PropertyFlip.STATE_RENOVATED
