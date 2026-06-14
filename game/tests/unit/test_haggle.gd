extends RefCounted
## Unit tests for Haggle (see tests/run_tests.gd for the runner contract: test_* methods
## return true to pass).
##
## Covers the opening lowball, the offer climbing to a peak at the buyer's patience, the
## decline when you over-push, the insulted floor and the never-full-worth ceiling, accept()
## locking the price, and ctor clamping. Default params: opening 0.5, concession 0.1,
## patience 4, max 0.95, annoyance 0.15 — so on a $1000 item the offer runs 500 → 900 (peak)
## → back down.


func test_opening_is_lowball() -> bool:
	var h := Haggle.new(1000)
	return h.current_offer() == 500 and h.rounds_pushed() == 0 and not h.is_settled()


func test_pushing_raises_offer() -> bool:
	var h := Haggle.new(1000)
	var first := h.push()  # round 1 -> 0.6
	var second := h.push()  # round 2 -> 0.7
	return first == 600 and second == 700 and h.rounds_pushed() == 2


func test_peaks_at_patience() -> bool:
	var h := Haggle.new(1000)
	for _i in 4:  # patience
		h.push()
	return h.current_offer() == 900  # 0.5 + 0.1*4 = 0.9


func test_first_over_push_step_declines() -> bool:
	var h := Haggle.new(1000)
	for _i in 5:  # exactly one past patience -> first decline step
		h.push()
	return h.current_offer() == 750  # peak 0.9 - annoyance 0.15 = 0.75


func test_over_pushing_declines() -> bool:
	var h := Haggle.new(1000)
	for _i in 6:  # 2 past patience
		h.push()
	# peak 0.9 - annoyance 0.15*2 = 0.6
	return h.current_offer() == 600 and h.current_offer() < 900


func test_cap_before_patience_still_declines() -> bool:
	# Concession hits the cap before patience (peak_uncapped 0.5+0.3*2=1.1 > 0.9). Over-pushing
	# must STILL slide down from the capped peak, not stay pinned at max.
	var h := Haggle.new(1000, 0.5, 0.3, 2, 0.9, 0.2)
	for _i in 3:  # one past patience=2
		h.push()
	return h.current_offer() == 700  # capped peak 0.9 - annoyance 0.2 = 0.7


func test_zero_patience_declines_immediately() -> bool:
	var h := Haggle.new(1000, 0.5, 0.1, 0, 0.95, 0.15)
	var opening := h.current_offer()  # round 0 -> opening 0.5
	h.push()  # round 1, already past patience 0 -> declines
	return opening == 500 and h.current_offer() < opening


func test_offer_floored_when_badly_overplayed() -> bool:
	var h := Haggle.new(1000)
	for _i in 30:  # way past patience -> would go negative, floored
		h.push()
	return h.current_offer() == 100  # MIN_FRACTION 0.1


func test_offer_capped_at_max_fraction() -> bool:
	# High opening + concession would exceed max; the offer must cap at max_fraction.
	var h := Haggle.new(1000, 0.8, 0.2, 4, 0.9)
	h.push()  # 0.8 + 0.2 = 1.0 -> capped 0.9
	return h.current_offer() == 900


func test_accept_locks_price() -> bool:
	var h := Haggle.new(1000)
	h.push()
	h.push()  # round 2 -> 0.7 -> 700
	var price := h.accept()
	var after_more := h.push()  # no-op once settled
	return price == 700 and h.is_settled() and h.final_price() == 700 and after_more == 700


func test_zero_value() -> bool:
	var h := Haggle.new(0)
	h.push()
	return h.current_offer() == 0 and h.accept() == 0


func test_ctor_clamps() -> bool:
	# opening below the floor and patience negative both clamp.
	var h := Haggle.new(-100, -1.0, -0.5, -3, 2.0, -1.0)
	return (
		h.item_value == 0
		and is_equal_approx(h.opening_fraction, Haggle.MIN_FRACTION)
		and h.patience == 0
		and h.max_fraction <= 1.0
		and h.concession == 0.0
		and h.annoyance == 0.0
	)
