extends RefCounted
## Unit tests for ExplosionModel (see tests/run_tests.gd: test_* returns true to
## pass). Curve under test is LINEAR falloff. Concrete 3D positions throughout.

# --- falloff ---------------------------------------------------------------


func test_falloff_full_at_center() -> bool:
	return is_equal_approx(ExplosionModel.falloff(0.0, 10.0), 1.0)


func test_falloff_zero_at_and_beyond_radius() -> bool:
	# 0 exactly at the radius and clamped to 0 past it.
	return (
		is_equal_approx(ExplosionModel.falloff(10.0, 10.0), 0.0)
		and is_equal_approx(ExplosionModel.falloff(25.0, 10.0), 0.0)
	)


func test_falloff_half_at_mid_radius() -> bool:
	# Linear: at half the radius the curve reads 0.5.
	return is_equal_approx(ExplosionModel.falloff(5.0, 10.0), 0.5)


func test_falloff_zero_radius_is_zero() -> bool:
	return is_equal_approx(ExplosionModel.falloff(0.0, 0.0), 0.0)


# --- damage_at -------------------------------------------------------------


func test_damage_full_at_center() -> bool:
	var c := Vector3(4.0, 1.0, -2.0)
	return is_equal_approx(ExplosionModel.damage_at(c, c, 100.0, 8.0), 100.0)


func test_damage_half_at_mid_radius() -> bool:
	# Target 5 units up from centre, radius 10 → linear 0.5 → 50 damage.
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(0.0, 5.0, 0.0)
	return is_equal_approx(ExplosionModel.damage_at(c, t, 100.0, 10.0), 50.0)


func test_damage_zero_at_radius() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(10.0, 0.0, 0.0)
	return is_equal_approx(ExplosionModel.damage_at(c, t, 100.0, 10.0), 0.0)


func test_damage_zero_beyond_radius() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(0.0, 0.0, 30.0)
	return is_equal_approx(ExplosionModel.damage_at(c, t, 100.0, 10.0), 0.0)


func test_damage_never_negative() -> bool:
	# Negative max_damage is floored to 0, never produces healing.
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(3.0, 0.0, 0.0)
	return ExplosionModel.damage_at(c, t, -50.0, 10.0) >= 0.0


func test_damage_uses_full_3d_distance() -> bool:
	# Diagonal (3,4,0) is 5 units out; radius 10 → 0.5 → 50.
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(3.0, 4.0, 0.0)
	return is_equal_approx(ExplosionModel.damage_at(c, t, 100.0, 10.0), 50.0)


# --- knockback -------------------------------------------------------------


func test_knockback_points_away_from_center() -> bool:
	# Target at half radius on +x: pushed outward in +x with magnitude
	# strength*1 (0.5*100 = 50), no z drift.
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(5.0, 0.0, 0.0)
	var k := ExplosionModel.knockback(c, t, 100.0, 10.0)
	return k.x > 0.0 and is_equal_approx(k.x, 50.0) and is_equal_approx(k.z, 0.0)


func test_knockback_has_upward_component() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(0.0, 0.0, 4.0)
	var k := ExplosionModel.knockback(c, t, 100.0, 10.0)
	return k.y > 0.0


func test_knockback_shrinks_with_distance() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var near := ExplosionModel.knockback(c, Vector3(2.0, 0.0, 0.0), 100.0, 10.0)
	var far := ExplosionModel.knockback(c, Vector3(8.0, 0.0, 0.0), 100.0, 10.0)
	return near.length() > far.length()


func test_knockback_zero_beyond_radius() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(20.0, 0.0, 0.0)
	return ExplosionModel.knockback(c, t, 100.0, 10.0) == Vector3.ZERO


func test_knockback_zero_at_radius() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var t := Vector3(10.0, 0.0, 0.0)
	return ExplosionModel.knockback(c, t, 100.0, 10.0) == Vector3.ZERO


func test_knockback_center_no_nan_pure_vertical() -> bool:
	# Exact centre: no outward direction, still lifts straight up, never NaN.
	var c := Vector3(7.0, 2.0, 3.0)
	var k := ExplosionModel.knockback(c, c, 100.0, 10.0)
	var finite := not (is_nan(k.x) or is_nan(k.y) or is_nan(k.z))
	return finite and is_equal_approx(k.x, 0.0) and is_equal_approx(k.z, 0.0) and k.y > 0.0


# --- is_in_blast -----------------------------------------------------------


func test_in_blast_inside() -> bool:
	return ExplosionModel.is_in_blast(Vector3.ZERO, Vector3(0.0, 0.0, 9.99), 10.0)


func test_in_blast_boundary_excluded() -> bool:
	return not ExplosionModel.is_in_blast(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 10.0)


func test_in_blast_outside() -> bool:
	return not ExplosionModel.is_in_blast(Vector3.ZERO, Vector3(11.0, 0.0, 0.0), 10.0)


# --- should_chain ----------------------------------------------------------


func test_should_chain_within_trigger() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var car := Vector3(3.0, 0.0, 0.0)
	return ExplosionModel.should_chain(c, car, 5.0)


func test_should_chain_at_trigger_inclusive() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var barrel := Vector3(5.0, 0.0, 0.0)
	return ExplosionModel.should_chain(c, barrel, 5.0)


func test_should_chain_false_beyond_trigger() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var car := Vector3(0.0, 0.0, 9.0)
	return not ExplosionModel.should_chain(c, car, 5.0)


# --- apply_to_many ---------------------------------------------------------


func test_apply_to_many_only_in_blast() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var targets: Array = [
		Vector3(0.0, 0.0, 0.0),  # index 0: centre, in blast
		Vector3(5.0, 0.0, 0.0),  # index 1: mid, in blast
		Vector3(20.0, 0.0, 0.0),  # index 2: outside
	]
	var hits := ExplosionModel.apply_to_many(c, targets, 100.0, 10.0)
	return hits.size() == 2 and hits[0]["index"] == 0 and hits[1]["index"] == 1


func test_apply_to_many_damage_values() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var targets: Array = [Vector3(0.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0)]
	var hits := ExplosionModel.apply_to_many(c, targets, 100.0, 10.0)
	return is_equal_approx(hits[0]["damage"], 100.0) and is_equal_approx(hits[1]["damage"], 50.0)


func test_apply_to_many_empty_when_none_in_blast() -> bool:
	var c := Vector3(0.0, 0.0, 0.0)
	var targets: Array = [Vector3(50.0, 0.0, 0.0), Vector3(0.0, 60.0, 0.0)]
	return ExplosionModel.apply_to_many(c, targets, 100.0, 10.0).is_empty()
