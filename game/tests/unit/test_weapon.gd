extends RefCounted
## Unit tests for Weapon (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


# A small, predictable stats block so assertions use round numbers.
static func _stats() -> WeaponStats:
	var s := WeaponStats.new()
	s.fire_rate = 10.0  # 0.1s cooldown
	s.mag_size = 5
	s.reserve_max = 10
	s.reload_time = 2.0
	s.base_spread = 0.01
	s.spread_per_shot = 0.05
	s.max_spread = 0.20
	s.spread_recovery = 0.10
	return s


func test_starts_full() -> bool:
	var w := Weapon.new(_stats())
	return w.ammo == 5 and w.reserve == 10


func test_start_reserve_override() -> bool:
	var w := Weapon.new(_stats(), 3)
	return w.reserve == 3


func test_fire_consumes_a_round() -> bool:
	var w := Weapon.new(_stats())
	var fired := w.fire()
	return fired and w.ammo == 4


func test_cannot_fire_twice_without_cooldown() -> bool:
	var w := Weapon.new(_stats())
	w.fire()
	return not w.can_fire() and not w.fire()


func test_cooldown_clears_after_tick() -> bool:
	var w := Weapon.new(_stats())
	w.fire()
	w.tick(0.1)
	return w.can_fire()


func test_empty_mag_cannot_fire() -> bool:
	var w := Weapon.new(_stats())
	for _i in range(5):
		w.fire()
		w.tick(0.1)
	return w.ammo == 0 and not w.can_fire()


func test_reload_refills_from_reserve() -> bool:
	var w := Weapon.new(_stats())
	for _i in range(5):
		w.fire()
		w.tick(0.1)
	var started := w.start_reload()
	w.tick(2.0)
	return started and w.ammo == 5 and w.reserve == 5


func test_partial_reload_only_takes_what_is_needed() -> bool:
	var w := Weapon.new(_stats())
	w.fire()  # one round gone
	w.tick(0.1)
	w.start_reload()
	w.tick(2.0)
	# Only 1 round needed to top up the mag of 5.
	return w.ammo == 5 and w.reserve == 9


func test_cannot_reload_full_mag() -> bool:
	var w := Weapon.new(_stats())
	return not w.start_reload()


func test_cannot_reload_without_reserve() -> bool:
	var w := Weapon.new(_stats(), 0)
	w.fire()
	w.tick(0.1)
	return not w.start_reload()


func test_cannot_fire_while_reloading() -> bool:
	var w := Weapon.new(_stats())
	w.fire()
	w.tick(0.1)
	w.start_reload()
	return not w.can_fire()


func test_reload_clamps_to_available_reserve() -> bool:
	var w := Weapon.new(_stats(), 2)
	for _i in range(5):
		w.fire()
		w.tick(0.1)
	w.start_reload()
	w.tick(2.0)
	# Only 2 spare rounds exist, so the mag of 5 only gets 2.
	return w.ammo == 2 and w.reserve == 0


func test_spread_grows_on_fire() -> bool:
	var w := Weapon.new(_stats())
	var before := w.spread
	w.fire()
	return w.spread > before and is_equal_approx(w.spread, 0.06)


func test_spread_clamps_to_max() -> bool:
	var w := Weapon.new(_stats())
	for _i in range(20):
		w.fire()
		w.tick(0.1)
	return w.spread <= 0.20 + 0.0001


func test_spread_recovers_toward_base() -> bool:
	var w := Weapon.new(_stats())
	w.fire()  # spread 0.06
	for _i in range(100):
		w.tick(0.1)
	return is_equal_approx(w.spread, 0.01)
