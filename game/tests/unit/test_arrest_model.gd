extends RefCounted
## Unit tests for ArrestModel (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Pure "Busted" math — no scene.

# --- cornered -------------------------------------------------------------


func test_cornered_when_wanted_and_close() -> bool:
	return ArrestModel.cornered(2, 1.5, 1.8)


func test_not_cornered_when_out_of_reach() -> bool:
	return not ArrestModel.cornered(2, 5.0, 1.8)


func test_not_cornered_when_not_wanted() -> bool:
	# No heat → no arrest, even if a cop is standing on you.
	return not ArrestModel.cornered(0, 0.5, 1.8)


# --- tick_grapple ---------------------------------------------------------


func test_grapple_builds_while_cornered() -> bool:
	return is_equal_approx(ArrestModel.tick_grapple(0.5, true, 0.25), 0.75)


func test_grapple_decays_when_free() -> bool:
	return is_equal_approx(ArrestModel.tick_grapple(0.5, false, 0.2), 0.3)


func test_grapple_never_negative() -> bool:
	return is_equal_approx(ArrestModel.tick_grapple(0.1, false, 0.5), 0.0)


# --- is_busted ------------------------------------------------------------


func test_busted_at_grapple_time() -> bool:
	return ArrestModel.is_busted(1.5, 1.5) and ArrestModel.is_busted(2.0, 1.5)


func test_not_busted_before_grapple_time() -> bool:
	return not ArrestModel.is_busted(1.0, 1.5)


func test_zero_grapple_time_never_busts() -> bool:
	return not ArrestModel.is_busted(99.0, 0.0)


# --- cash penalty ---------------------------------------------------------


func test_cash_after_bust_takes_fraction() -> bool:
	return ArrestModel.cash_after_bust(1000, 0.10) == 900


func test_cash_after_bust_floors() -> bool:
	# 333 * 0.9 = 299.7 → floored to 299 kept.
	return ArrestModel.cash_after_bust(333, 0.10) == 299


func test_full_penalty_empties_wallet() -> bool:
	return ArrestModel.cash_after_bust(1000, 1.0) == 0


func test_zero_penalty_keeps_wallet() -> bool:
	return ArrestModel.cash_after_bust(1000, 0.0) == 1000


func test_bust_fee_complements_kept_cash() -> bool:
	var wallet := 1000
	var fee := ArrestModel.bust_fee(wallet, 0.10)
	return fee == 100 and fee + ArrestModel.cash_after_bust(wallet, 0.10) == wallet


func test_bust_fee_never_negative() -> bool:
	return ArrestModel.bust_fee(0, 0.10) == 0
