extends RefCounted
## Unit tests for Damageable (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_at_full_health() -> bool:
	var d := Damageable.new(50.0)
	return is_equal_approx(d.health, 50.0) and not d.is_dead()


func test_apply_reduces_health() -> bool:
	var d := Damageable.new(50.0)
	d.apply(20.0)
	return is_equal_approx(d.health, 30.0)


func test_negative_damage_ignored() -> bool:
	var d := Damageable.new(50.0)
	d.apply(-10.0)
	return is_equal_approx(d.health, 50.0)


func test_apply_returns_true_only_on_killing_blow() -> bool:
	var d := Damageable.new(50.0)
	var first := d.apply(30.0)
	var second := d.apply(30.0)
	return not first and second


func test_health_never_negative() -> bool:
	var d := Damageable.new(50.0)
	d.apply(999.0)
	return is_equal_approx(d.health, 0.0) and d.is_dead()


func test_damage_to_dead_returns_false() -> bool:
	var d := Damageable.new(10.0)
	d.apply(10.0)
	return not d.apply(10.0)


func test_health_fraction() -> bool:
	var d := Damageable.new(40.0)
	d.apply(10.0)
	return is_equal_approx(d.health_fraction(), 0.75)


func test_revive_restores_full() -> bool:
	var d := Damageable.new(40.0)
	d.apply(40.0)
	d.revive()
	return is_equal_approx(d.health, 40.0) and not d.is_dead()


func test_zero_max_is_clamped_safe() -> bool:
	# A degenerate 0 max must not divide by zero in health_fraction().
	var d := Damageable.new(0.0)
	return d.health_fraction() >= 0.0
