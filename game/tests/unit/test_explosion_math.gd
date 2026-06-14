extends RefCounted
## Unit tests for ExplosionMath (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_full_damage_at_centre() -> bool:
	return is_equal_approx(ExplosionMath.radial_damage(0.0, 2.5, 7.5, 120.0), 120.0)


func test_full_damage_inside_inner() -> bool:
	return is_equal_approx(ExplosionMath.radial_damage(2.5, 2.5, 7.5, 120.0), 120.0)


func test_zero_at_outer() -> bool:
	return is_equal_approx(ExplosionMath.radial_damage(7.5, 2.5, 7.5, 120.0), 0.0)


func test_zero_beyond_outer() -> bool:
	return is_equal_approx(ExplosionMath.radial_damage(20.0, 2.5, 7.5, 120.0), 0.0)


func test_linear_midpoint() -> bool:
	# Midpoint of [2.5, 7.5] is 5.0 → half damage.
	return is_equal_approx(ExplosionMath.radial_damage(5.0, 2.5, 7.5, 120.0), 60.0)


func test_degenerate_radii_safe() -> bool:
	# Zero-width / inverted band describes no real blast volume → no damage
	# anywhere, and no divide-by-zero.
	return (
		is_equal_approx(ExplosionMath.radial_damage(0.0, 5.0, 5.0, 120.0), 0.0)
		and is_equal_approx(ExplosionMath.radial_damage(3.0, 5.0, 5.0, 120.0), 0.0)
	)
