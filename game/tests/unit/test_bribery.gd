extends RefCounted
## Unit tests for Bribery (see tests/run_tests.gd for the runner contract: test_* methods
## return true to pass).
##
## Covers the heat-scaled price, a full/over offer being accepted at the going price, a short
## offer quietly refused, an insulting lowball backfiring, the insult boundary, and ctor
## clamping. Default params: base 1000, per-star 1500, insult 0.5 — so a 3-star price is $5500.


func test_price_scales_with_heat() -> bool:
	var b := Bribery.new()
	return b.price_for(0) == 1000 and b.price_for(3) == 5500 and b.price_for(5) == 8500


func test_full_offer_bribes() -> bool:
	var b := Bribery.new()
	var r := b.attempt(5500, 3)
	return String(r["outcome"]) == "bribed" and int(r["spent"]) == 5500


func test_over_offer_still_pays_only_price() -> bool:
	var b := Bribery.new()
	var r := b.attempt(11000, 3)  # double the ask
	return String(r["outcome"]) == "bribed" and int(r["spent"]) == 5500


func test_short_offer_refused() -> bool:
	var b := Bribery.new()
	var r := b.attempt(3850, 3)  # 0.7 * 5500, above the insult line
	return String(r["outcome"]) == "refused" and int(r["spent"]) == 0


func test_lowball_backfires() -> bool:
	var b := Bribery.new()
	var r := b.attempt(1100, 3)  # 0.2 * 5500, an insult
	return String(r["outcome"]) == "backfired" and int(r["spent"]) == 0


func test_insult_boundary() -> bool:
	var b := Bribery.new()
	var at := b.attempt(2750, 3)  # exactly 0.5 * 5500 -> still refused (>=)
	var below := b.attempt(2749, 3)  # one under -> backfires
	return String(at["outcome"]) == "refused" and String(below["outcome"]) == "backfired"


func test_zero_stars_price_is_base() -> bool:
	var b := Bribery.new()
	var r := b.attempt(1000, 0)
	return b.price_for(0) == 1000 and String(r["outcome"]) == "bribed"


func test_ctor_clamps() -> bool:
	var b := Bribery.new(-500, -100, 2.0)
	return b.base_price == 0 and b.price_per_star == 0 and b.insult_fraction <= 1.0
