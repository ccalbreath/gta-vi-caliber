extends RefCounted
## Unit tests for PlayerHealthModel (see tests/run_tests.gd for the runner
## contract: test_* methods return true to pass).


func test_starts_full() -> bool:
	var h := PlayerHealthModel.new(100.0)
	return is_equal_approx(h.health, 100.0) and not h.is_dead()


func test_damage_reduces_health() -> bool:
	var h := PlayerHealthModel.new(100.0)
	h.apply(30.0)
	return is_equal_approx(h.health, 70.0)


func test_negative_damage_ignored() -> bool:
	var h := PlayerHealthModel.new(100.0)
	h.apply(-20.0)
	return is_equal_approx(h.health, 100.0)


func test_death_on_lethal_hit() -> bool:
	var h := PlayerHealthModel.new(50.0)
	return h.apply(60.0) and h.is_dead() and is_equal_approx(h.health, 0.0)


func test_no_regen_during_delay() -> bool:
	var h := PlayerHealthModel.new(100.0, 10.0, 5.0)
	h.apply(40.0)
	h.tick(2.0)  # within the 5s delay
	return is_equal_approx(h.health, 60.0)


func test_regen_after_delay() -> bool:
	var h := PlayerHealthModel.new(100.0, 10.0, 5.0)
	h.apply(40.0)
	h.tick(5.0)  # reaches the delay; this frame also regenerates 10*5? no — see below
	# After crossing the delay, regen applies at regen_rate * delta for the frames
	# beyond it. Tick once past the threshold, then a 1s frame regenerates 10.
	h.tick(1.0)
	return h.health > 60.0


func test_regen_caps_at_max() -> bool:
	var h := PlayerHealthModel.new(100.0, 10.0, 0.0)
	h.apply(5.0)
	for _i in range(100):
		h.tick(1.0)
	return is_equal_approx(h.health, 100.0)


func test_damage_resets_regen_timer() -> bool:
	var h := PlayerHealthModel.new(100.0, 10.0, 5.0)
	h.apply(40.0)
	h.tick(4.9)  # almost at delay
	h.apply(0.0)  # a graze resets the timer
	h.tick(1.0)  # would-be-regen frame, but timer reset → still no regen
	return is_equal_approx(h.health, 60.0)


func test_dead_does_not_regen() -> bool:
	var h := PlayerHealthModel.new(50.0, 10.0, 0.0)
	h.apply(50.0)
	h.tick(5.0)
	return h.is_dead() and is_equal_approx(h.health, 0.0)


func test_fraction() -> bool:
	var h := PlayerHealthModel.new(80.0)
	h.apply(20.0)
	return is_equal_approx(h.fraction(), 0.75)


func test_revive_restores_full() -> bool:
	var h := PlayerHealthModel.new(80.0)
	h.apply(80.0)
	h.revive()
	return is_equal_approx(h.health, 80.0) and not h.is_dead()
