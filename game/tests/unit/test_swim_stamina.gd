extends RefCounted
## Unit tests for SwimStamina (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_starts_full() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	return (
		is_equal_approx(s.oxygen(), 20.0)
		and is_equal_approx(s.stamina(), 100.0)
		and is_equal_approx(s.oxygen_fraction(), 1.0)
		and is_equal_approx(s.stamina_fraction(), 1.0)
	)


func test_oxygen_drains_underwater() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 1.0)
	# Surface pressure (depth 0) = 1 atm, so drain is the base 1.0/s.
	return is_equal_approx(s.oxygen(), 19.0)


func test_oxygen_drains_faster_at_depth() -> bool:
	var shallow := SwimStamina.new(20.0, 100.0)
	var deep := SwimStamina.new(20.0, 100.0)
	shallow.update(true, false, 0.0, 1.0)
	deep.update(true, false, 10.0, 1.0)
	# 10 m = 2 atm, so the deep diver loses twice the oxygen the shallow one does.
	var shallow_lost := 20.0 - shallow.oxygen()
	var deep_lost := 20.0 - deep.oxygen()
	return deep_lost > shallow_lost and is_equal_approx(deep_lost, 2.0)


func test_oxygen_refills_at_surface() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 10.0)
	var drained: float = s.oxygen()
	s.update(false, false, 0.0, 1.0)
	return s.oxygen() > drained and is_equal_approx(s.oxygen(), drained + 5.0)


func test_oxygen_clamped_to_zero() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 1000.0)
	return is_equal_approx(s.oxygen(), 0.0)


func test_oxygen_clamped_to_max() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(false, false, 0.0, 1000.0)
	return is_equal_approx(s.oxygen(), 20.0)


func test_stamina_drains_swimming() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 1.0)
	return is_equal_approx(s.stamina(), 96.0)


func test_stamina_drains_faster_sprinting() -> bool:
	var cruise := SwimStamina.new(20.0, 100.0)
	var sprint := SwimStamina.new(20.0, 100.0)
	cruise.update(true, false, 0.0, 1.0)
	sprint.update(true, true, 0.0, 1.0)
	# Base 4/s vs base+extra 12/s.
	return is_equal_approx(cruise.stamina(), 96.0) and is_equal_approx(sprint.stamina(), 88.0)


func test_stamina_recovers_idle() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 5.0)
	var tired: float = s.stamina()
	# Idle at the surface (not underwater, depth 0) recovers stamina.
	s.update(false, false, 0.0, 1.0)
	return s.stamina() > tired and is_equal_approx(s.stamina(), tired + 3.0)


func test_stamina_clamped_to_zero() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, true, 0.0, 1000.0)
	return is_equal_approx(s.stamina(), 0.0)


func test_stamina_clamped_to_max() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(false, false, 0.0, 1000.0)
	return is_equal_approx(s.stamina(), 100.0)


func test_is_drowning_only_at_zero_oxygen_underwater() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	if s.is_drowning(true):
		return false
	s.update(true, false, 0.0, 1000.0)
	# Out of air and still under -> drowning; surfacing stops it.
	return s.is_drowning(true) and not s.is_drowning(false)


func test_is_exhausted_at_zero_stamina() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	if s.is_exhausted():
		return false
	s.update(true, true, 0.0, 1000.0)
	return s.is_exhausted()


func test_drown_damage_zero_with_air() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	return is_equal_approx(s.drown_damage(true, 1.0, 10.0), 0.0)


func test_drown_damage_positive_without_air() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 1000.0)
	return is_equal_approx(s.drown_damage(true, 0.5, 10.0), 5.0)


func test_drown_damage_zero_at_surface_even_without_air() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 1000.0)
	return is_equal_approx(s.drown_damage(false, 1.0, 10.0), 0.0)


func test_drown_damage_guards_negative() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, false, 0.0, 1000.0)
	return (
		is_equal_approx(s.drown_damage(true, -1.0, 10.0), 0.0)
		and is_equal_approx(s.drown_damage(true, 1.0, -10.0), 0.0)
	)


func test_swim_speed_base_when_fresh() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	return is_equal_approx(s.swim_speed(5.0, false), 5.0)


func test_swim_speed_faster_sprinting() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	return is_equal_approx(s.swim_speed(5.0, true), 8.0)


func test_swim_speed_slower_exhausted() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, true, 0.0, 1000.0)
	# Exhausted: throttled, and the sprint flag no longer grants a boost.
	return (
		is_equal_approx(s.swim_speed(5.0, false), 2.5)
		and is_equal_approx(s.swim_speed(5.0, true), 2.5)
	)


func test_pressure_rises_with_depth_and_guards_negative() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	return (
		is_equal_approx(s.pressure_at(0.0), 1.0)
		and is_equal_approx(s.pressure_at(10.0), 2.0)
		and s.pressure_at(20.0) > s.pressure_at(10.0)
		and is_equal_approx(s.pressure_at(-50.0), 1.0)
	)  # negative depth clamps to surface


func test_update_guards_negative_delta() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, true, 10.0, -5.0)
	return is_equal_approx(s.oxygen(), 20.0) and is_equal_approx(s.stamina(), 100.0)


func test_surface_refills_breath_only() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, true, 0.0, 3.0)
	var tired: float = s.stamina()
	s.surface()
	# Breath full again, stamina untouched.
	return is_equal_approx(s.oxygen(), 20.0) and is_equal_approx(s.stamina(), tired)


func test_reset_restores_both() -> bool:
	var s := SwimStamina.new(20.0, 100.0)
	s.update(true, true, 5.0, 100.0)
	s.reset()
	return is_equal_approx(s.oxygen(), 20.0) and is_equal_approx(s.stamina(), 100.0)
