extends RefCounted
## Unit tests for Ballistics (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).

const FWD := Vector3(0, 0, -1)
const RIGHT := Vector3(1, 0, 0)
const UP := Vector3(0, 1, 0)


func test_zero_spread_returns_forward() -> bool:
	var dir := Ballistics.spread_direction(FWD, RIGHT, UP, Vector2(1, 1), 0.0)
	return dir.is_equal_approx(FWD)


func test_zero_sample_returns_forward() -> bool:
	var dir := Ballistics.spread_direction(FWD, RIGHT, UP, Vector2.ZERO, 0.1)
	return dir.is_equal_approx(FWD)


func test_spread_result_is_normalized() -> bool:
	var dir := Ballistics.spread_direction(FWD, RIGHT, UP, Vector2(0.7, -0.3), 0.15)
	return is_equal_approx(dir.length(), 1.0)


func test_spread_pushes_toward_sample_axis() -> bool:
	# A positive x sample should tilt the shot to +x.
	var dir := Ballistics.spread_direction(FWD, RIGHT, UP, Vector2(1, 0), 0.1)
	return dir.x > 0.0


func test_wider_spread_tilts_further() -> bool:
	var narrow := Ballistics.spread_direction(FWD, RIGHT, UP, Vector2(1, 0), 0.05)
	var wide := Ballistics.spread_direction(FWD, RIGHT, UP, Vector2(1, 0), 0.15)
	return wide.x > narrow.x


func test_full_damage_inside_falloff() -> bool:
	return is_equal_approx(Ballistics.damage_at_range(20.0, 10.0, 25.0, 90.0, 0.5), 20.0)


func test_min_damage_beyond_falloff() -> bool:
	return is_equal_approx(Ballistics.damage_at_range(20.0, 100.0, 25.0, 90.0, 0.5), 10.0)


func test_damage_lerps_in_band() -> bool:
	# Midpoint of [25, 90] → halfway between full (20) and min (10) = 15.
	var mid := Ballistics.damage_at_range(20.0, 57.5, 25.0, 90.0, 0.5)
	return is_equal_approx(mid, 15.0)


func test_degenerate_band_is_safe() -> bool:
	# end <= start must not divide by zero.
	return is_equal_approx(Ballistics.damage_at_range(20.0, 50.0, 30.0, 30.0, 0.5), 10.0)


func test_disk_sample_within_unit_circle() -> bool:
	for i in range(0, 11):
		for j in range(0, 11):
			var p := Ballistics.disk_sample(float(i) / 10.0, float(j) / 10.0)
			if p.length() > 1.0001:
				return false
	return true


func test_disk_sample_zero_radius_is_centre() -> bool:
	return Ballistics.disk_sample(0.0, 0.5).is_zero_approx()


func test_zone_multiplier_headshot() -> bool:
	return is_equal_approx(Ballistics.zone_multiplier(1.7, 1.5, 2.0), 2.0)


func test_zone_multiplier_body() -> bool:
	return is_equal_approx(Ballistics.zone_multiplier(1.0, 1.5, 2.0), 1.0)


func test_zone_multiplier_boundary_is_headshot() -> bool:
	# Exactly at the head line counts as a headshot.
	return is_equal_approx(Ballistics.zone_multiplier(1.5, 1.5, 2.0), 2.0)
