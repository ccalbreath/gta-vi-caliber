extends RefCounted
## Unit tests for VehicleHealth (see tests/run_tests.gd: test_* methods return
## true to pass). Deterministic, no RNG. Concrete numbers: max 1000, fire at 0.2.


func test_starts_pristine() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	return (
		is_equal_approx(v.health(), 1000.0)
		and v.state() == VehicleHealth.State.PRISTINE
		and is_equal_approx(v.health_fraction(), 1.0)
		and not v.is_on_fire()
		and not v.is_wrecked()
	)


func test_pristine_at_two_thirds_boundary() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(340.0)  # 0.66 fraction -> still PRISTINE
	return v.state() == VehicleHealth.State.PRISTINE


func test_drops_to_damaged() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(400.0)  # 0.60 fraction
	return v.state() == VehicleHealth.State.DAMAGED


func test_drops_to_smoking() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(750.0)  # 0.25 fraction, below 0.33, above 0.2
	return v.state() == VehicleHealth.State.SMOKING and not v.is_on_fire()


func test_drops_to_on_fire() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(850.0)  # 0.15 fraction, below fire threshold
	return v.is_on_fire() and v.state() == VehicleHealth.State.ON_FIRE


func test_on_fire_arms_the_fuse() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	return is_equal_approx(v.time_to_explosion(), 5.0)


func test_fuse_is_inf_before_fire() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(400.0)  # DAMAGED, not on fire
	return v.time_to_explosion() == INF


func test_tick_before_fire_is_noop() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(400.0)
	v.tick(3.0)
	return v.state() == VehicleHealth.State.DAMAGED and v.time_to_explosion() == INF


func test_tick_burns_fuse_down() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	v.tick(2.0)
	return is_equal_approx(v.time_to_explosion(), 3.0) and v.is_on_fire()


func test_time_to_explosion_decreases_while_burning() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	var before := v.time_to_explosion()
	v.tick(1.0)
	var after := v.time_to_explosion()
	return after < before and is_equal_approx(after, 4.0)


func test_fuse_elapsed_wrecks() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	v.tick(5.0)
	return (
		v.is_wrecked()
		and v.state() == VehicleHealth.State.WRECKED
		and is_equal_approx(v.health(), 0.0)
		and is_equal_approx(v.time_to_explosion(), 0.0)
	)


func test_fuse_does_not_rearm_across_ticks() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	v.tick(1.0)
	v.apply_damage(10.0)  # still on fire; fuse must keep counting from 4.0
	return is_equal_approx(v.time_to_explosion(), 4.0)


func test_massive_hit_instant_wreck() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(5000.0)
	return (
		v.is_wrecked()
		and is_equal_approx(v.health(), 0.0)
		and is_equal_approx(v.time_to_explosion(), 0.0)
	)


func test_health_floors_at_zero() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(2000.0)
	return is_equal_approx(v.health(), 0.0) and is_equal_approx(v.health_fraction(), 0.0)


func test_just_exploded_is_one_shot() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(5000.0)
	return v.just_exploded() and not v.just_exploded()


func test_just_exploded_false_before_wreck() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(850.0)  # on fire, not yet exploded
	return not v.just_exploded()


func test_explosion_fires_once_via_fuse() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	v.tick(5.0)
	return v.just_exploded() and not v.just_exploded()


func test_negative_damage_ignored() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(-300.0)
	return is_equal_approx(v.health(), 1000.0) and v.state() == VehicleHealth.State.PRISTINE


func test_negative_delta_ignored() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	v.tick(-2.0)
	return is_equal_approx(v.time_to_explosion(), 5.0) and v.is_on_fire()


func test_wrecked_is_sticky_to_damage() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(5000.0)
	v.just_exploded()
	v.apply_damage(100.0)  # ignored once wrecked
	return v.is_wrecked() and is_equal_approx(v.health(), 0.0)


func test_wrecked_is_sticky_to_tick() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2, 5.0)
	v.apply_damage(850.0)
	v.tick(5.0)
	v.just_exploded()
	v.tick(3.0)  # no-op; stays wrecked, no second explosion
	return v.is_wrecked() and not v.just_exploded()


func test_repair_restores_pristine() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(850.0)
	v.repair()
	return (
		is_equal_approx(v.health(), 1000.0)
		and v.state() == VehicleHealth.State.PRISTINE
		and v.time_to_explosion() == INF
		and not v.is_on_fire()
	)


func test_reset_restores_after_wreck() -> bool:
	var v := VehicleHealth.new(1000.0, 0.2)
	v.apply_damage(5000.0)
	v.just_exploded()
	v.reset()
	return (
		is_equal_approx(v.health(), 1000.0)
		and v.state() == VehicleHealth.State.PRISTINE
		and not v.is_wrecked()
		and not v.just_exploded()
	)


func test_full_burn_down_timeline() -> bool:
	# PRISTINE -> DAMAGED -> SMOKING -> ON_FIRE -> (fuse) -> WRECKED
	var v := VehicleHealth.new(1000.0, 0.2, 4.0)
	var pristine := v.state() == VehicleHealth.State.PRISTINE
	v.apply_damage(400.0)
	var damaged := v.state() == VehicleHealth.State.DAMAGED
	v.apply_damage(350.0)  # 0.25 -> SMOKING
	var smoking := v.state() == VehicleHealth.State.SMOKING
	v.apply_damage(100.0)  # 0.15 -> ON_FIRE
	var on_fire := v.is_on_fire()
	v.tick(4.0)
	var wrecked := v.is_wrecked() and v.just_exploded()
	return pristine and damaged and smoking and on_fire and wrecked
