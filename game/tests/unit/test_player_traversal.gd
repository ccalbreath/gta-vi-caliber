extends RefCounted
## Unit tests for PlayerMotion's traversal/landing math — slope sliding and fall
## damage — split from test_player_motion.gd to stay under the per-file public-
## method cap. Runner contract: test_* methods return true to pass.


func test_slope_slide_flat_ground_is_zero() -> bool:
	return PlayerMotion.slope_slide(Vector3.UP, 0.82, 18.0) == Vector3.ZERO


func test_slope_slide_points_down_the_fall_line() -> bool:
	# A normal tilted toward +X (ramp rising toward -X): the fall line is +X.
	var slide := PlayerMotion.slope_slide(Vector3(0.707, 0.707, 0.0), 0.82, 18.0)
	return slide.x > 0.0 and absf(slide.z) < 0.0001 and slide.y == 0.0


func test_slope_slide_is_horizontal() -> bool:
	var slide := PlayerMotion.slope_slide(Vector3(0.5, 0.6, 0.6).normalized(), 0.82, 18.0)
	return slide.y == 0.0


func test_slope_slide_grows_with_steepness() -> bool:
	var gentle := PlayerMotion.slope_slide(Vector3(0.3, 0.81, 0.0).normalized(), 0.82, 18.0)
	var steep := PlayerMotion.slope_slide(Vector3(0.9, 0.3, 0.0).normalized(), 0.82, 18.0)
	return steep.length() > gentle.length()


func test_slope_slide_not_steep_enough_is_zero() -> bool:
	return PlayerMotion.slope_slide(Vector3(0.0, 0.95, 0.0), 0.82, 18.0) == Vector3.ZERO


func test_fall_damage_harmless_below_safe_speed() -> bool:
	return PlayerMotion.fall_damage(8.0, 9.0, 22.0, 100.0) == 0.0


func test_fall_damage_full_at_lethal_speed() -> bool:
	return absf(PlayerMotion.fall_damage(22.0, 9.0, 22.0, 100.0) - 100.0) < 0.0001


func test_fall_damage_clamps_above_lethal() -> bool:
	return absf(PlayerMotion.fall_damage(40.0, 9.0, 22.0, 100.0) - 100.0) < 0.0001


func test_fall_damage_interpolates() -> bool:
	# Halfway between 9 and 22 (=15.5) → half of max.
	return absf(PlayerMotion.fall_damage(15.5, 9.0, 22.0, 100.0) - 50.0) < 0.0001


func test_fall_damage_degenerate_range_safe() -> bool:
	return PlayerMotion.fall_damage(20.0, 9.0, 9.0, 100.0) == 0.0
