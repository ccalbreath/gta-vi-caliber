extends RefCounted
## Unit tests for CombatTextMotion (see tests/run_tests.gd for the runner
## contract: test_* methods return true to pass).


func test_rise_starts_at_zero() -> bool:
	return is_equal_approx(CombatTextMotion.rise(0.0, 1.0, 1.2), 0.0)


func test_rise_reaches_height_at_end() -> bool:
	return is_equal_approx(CombatTextMotion.rise(1.0, 1.0, 1.2), 1.2)


func test_rise_is_monotonic() -> bool:
	var prev := -1.0
	for i in range(0, 21):
		var value := CombatTextMotion.rise(float(i) / 20.0, 1.0, 1.2)
		if value < prev:
			return false
		prev = value
	return true


func test_rise_eases_out() -> bool:
	# Ease-out: more than half the height is covered by the halfway point.
	return CombatTextMotion.rise(0.5, 1.0, 1.0) > 0.5


func test_alpha_full_before_fade_start() -> bool:
	return is_equal_approx(CombatTextMotion.alpha(0.4, 1.0, 0.5), 1.0)


func test_alpha_zero_at_end() -> bool:
	return is_equal_approx(CombatTextMotion.alpha(1.0, 1.0, 0.5), 0.0)


func test_alpha_half_at_three_quarter_life() -> bool:
	# Fade starts at 0.5; three-quarters of the way is halfway through the fade.
	return is_equal_approx(CombatTextMotion.alpha(0.75, 1.0, 0.5), 0.5)


func test_is_done() -> bool:
	return CombatTextMotion.is_done(1.0, 1.0) and not CombatTextMotion.is_done(0.5, 1.0)


func test_zero_duration_is_safe() -> bool:
	# No divide-by-zero; a zero-life popup is immediately done and transparent.
	return CombatTextMotion.is_done(0.0, 0.0) and CombatTextMotion.alpha(0.0, 0.0) >= 0.0
