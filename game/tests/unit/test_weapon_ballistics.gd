extends RefCounted
## Unit tests for WeaponBallistics (see tests/run_tests.gd: test_* methods return
## true to pass). RNG is seeded for deterministic spread results. Related
## assertions are grouped to stay under gdlint's max-public-methods cap.


func test_damage_full_inside_and_at_start() -> bool:
	# Full damage anywhere inside falloff_start, including the boundary.
	return (
		is_equal_approx(WeaponBallistics.damage_at_range(40.0, 10.0, 25.0, 90.0, 0.45), 40.0)
		and is_equal_approx(WeaponBallistics.damage_at_range(40.0, 25.0, 25.0, 90.0, 0.45), 40.0)
	)


func test_damage_reduced_past_start() -> bool:
	# Midpoint of the 25..90 band lerps 1.0 -> 0.4: factor 0.7 -> 28.0.
	var dmg := WeaponBallistics.damage_at_range(40.0, 57.5, 25.0, 90.0, 0.4)
	return is_equal_approx(dmg, 28.0)


func test_damage_floored_at_and_beyond_end() -> bool:
	# Floor (base * 0.45 = 18) reached at falloff_end and held flat past it.
	return (
		is_equal_approx(WeaponBallistics.damage_at_range(40.0, 90.0, 25.0, 90.0, 0.45), 18.0)
		and is_equal_approx(WeaponBallistics.damage_at_range(40.0, 200.0, 25.0, 90.0, 0.45), 18.0)
	)


func test_damage_min_factor_clamped() -> bool:
	# min_factor > 1 clamps to 1: full damage past end, never amplified.
	return is_equal_approx(WeaponBallistics.damage_at_range(40.0, 300.0, 25.0, 90.0, 2.0), 40.0)


func test_damage_degenerate_band_snaps_to_floor() -> bool:
	# end <= start (collapsed band): a hard step at start — past it snaps to floor.
	return is_equal_approx(WeaponBallistics.damage_at_range(40.0, 60.0, 50.0, 50.0, 0.5), 20.0)


func test_damage_negative_distance_guarded() -> bool:
	return is_equal_approx(WeaponBallistics.damage_at_range(40.0, -5.0, 25.0, 90.0, 0.45), 40.0)


func test_multiplier_ordering_head_torso_limb() -> bool:
	# Head rewards precision, limbs punish it: head > torso > limb.
	return (
		WeaponBallistics.hit_multiplier("head") > WeaponBallistics.hit_multiplier("torso")
		and WeaponBallistics.hit_multiplier("torso") > WeaponBallistics.hit_multiplier("limb")
	)


func test_head_multiplier_value_and_case_insensitive() -> bool:
	return (
		is_equal_approx(WeaponBallistics.hit_multiplier("head"), 2.0)
		and is_equal_approx(WeaponBallistics.hit_multiplier("HEAD"), 2.0)
	)


func test_unknown_part_is_one() -> bool:
	return (
		is_equal_approx(WeaponBallistics.hit_multiplier("wing"), 1.0)
		and is_equal_approx(WeaponBallistics.hit_multiplier(""), 1.0)
	)


func test_spread_zero_returns_aim_unchanged() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var aim := Vector3(0.0, 0.0, -1.0)
	var out := WeaponBallistics.spread_direction(aim, 0.0, rng)
	return out.is_equal_approx(aim)


func test_spread_result_stays_normalized() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var aim := Vector3(0.0, 0.0, -1.0)
	var out := WeaponBallistics.spread_direction(aim, 0.1, rng)
	return is_equal_approx(out.length(), 1.0)


func test_spread_within_cone_angle() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var aim := Vector3(0.0, 1.0, 0.0).normalized()
	var spread := 0.15
	var ok := true
	var cos_limit := cos(spread)
	for _i in 64:
		var out := WeaponBallistics.spread_direction(aim, spread, rng)
		# Float slack so a shot exactly on the cone edge doesn't false-fail.
		if out.dot(aim) < cos_limit - 0.0001:
			ok = false
	return ok


func test_spread_actually_perturbs() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var aim := Vector3(0.0, 0.0, -1.0)
	var out := WeaponBallistics.spread_direction(aim, 0.1, rng)
	return not out.is_equal_approx(aim)


func test_spread_normalizes_aim_input() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# Non-unit, zero-spread aim should come back unit length along the same axis.
	var out := WeaponBallistics.spread_direction(Vector3(0.0, 0.0, -5.0), 0.0, rng)
	return out.is_equal_approx(Vector3(0.0, 0.0, -1.0))


func test_bloom_starts_at_min() -> bool:
	var b := WeaponBallistics.Bloom.new(0.01, 0.16, 0.02, 0.22)
	return is_equal_approx(b.current_spread(), 0.01)


func test_bloom_grows_with_shots() -> bool:
	var b := WeaponBallistics.Bloom.new(0.01, 0.16, 0.02, 0.22)
	b.add_shot()
	b.add_shot()
	return is_equal_approx(b.current_spread(), 0.05)


func test_bloom_capped_at_max() -> bool:
	var b := WeaponBallistics.Bloom.new(0.01, 0.16, 0.05, 0.22)
	for _i in 50:
		b.add_shot()
	return is_equal_approx(b.current_spread(), 0.16)


func test_bloom_recovers_toward_min() -> bool:
	var b := WeaponBallistics.Bloom.new(0.01, 0.16, 0.05, 0.10)
	b.add_shot()  # 0.06
	b.recover(0.2)  # -0.02 -> 0.04
	return is_equal_approx(b.current_spread(), 0.04)


func test_bloom_recover_floors_at_min() -> bool:
	var b := WeaponBallistics.Bloom.new(0.01, 0.16, 0.05, 0.10)
	b.add_shot()
	b.recover(100.0)
	return is_equal_approx(b.current_spread(), 0.01)


func test_bloom_reset_snaps_to_min() -> bool:
	var b := WeaponBallistics.Bloom.new(0.02, 0.16, 0.04, 0.22)
	b.add_shot()
	b.add_shot()
	b.reset()
	return is_equal_approx(b.current_spread(), 0.02)


func test_effective_damage_headshot_up_close() -> bool:
	# Inside falloff_start: full base, doubled for a headshot.
	var dmg := WeaponBallistics.effective_damage(30.0, 5.0, "head", 25.0, 90.0, 0.45)
	return is_equal_approx(dmg, 60.0)


func test_effective_damage_limb_at_range() -> bool:
	# Midpoint of band: factor 0.7 -> 21.0, limb 0.7 -> 14.7.
	var dmg := WeaponBallistics.effective_damage(30.0, 57.5, "limb", 25.0, 90.0, 0.4)
	return is_equal_approx(dmg, 14.7)


func test_time_to_kill_basic() -> bool:
	# 100 hp, 25 dmg/shot -> 4 shots; at 10/s the 4th lands at 0.3s.
	return is_equal_approx(WeaponBallistics.time_to_kill(25.0, 10.0, 100.0), 0.3)


func test_time_to_kill_one_shot_is_zero() -> bool:
	return is_equal_approx(WeaponBallistics.time_to_kill(100.0, 5.0, 80.0), 0.0)


func test_time_to_kill_no_damage_is_inf() -> bool:
	return WeaponBallistics.time_to_kill(0.0, 10.0, 100.0) == INF
