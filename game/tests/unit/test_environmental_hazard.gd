extends RefCounted
## Unit tests for EnvironmentalHazard (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers zone validation, XZ-plane coverage, damage summation + dt scaling +
## protection, dominant/strongest hazard queries, transient zones, and tick() expiry.


func test_default_zones_loaded() -> bool:
	var eh := EnvironmentalHazard.new()
	return eh.zone_count() == 3 and eh.has_zone("toxic_dump")


func test_malformed_dropped() -> bool:
	var eh := (
		EnvironmentalHazard
		. new(
			[
				{"id": "ok", "center": Vector3.ZERO, "radius": 10.0, "dps": 5.0},
				{"id": "", "center": Vector3.ZERO, "radius": 10.0, "dps": 5.0},  # empty id
				{"center": Vector3.ZERO, "radius": 10.0, "dps": 5.0},  # no id
				{"id": "bad", "center": Vector3.ZERO, "radius": -1.0, "dps": 5.0},  # bad radius
				{"id": "nodps", "center": Vector3.ZERO, "radius": 10.0, "dps": 0.0},  # bad dps
				{"id": "ok", "center": Vector3.ZERO, "radius": 99.0, "dps": 9.0},  # duplicate
			]
		)
	)
	return eh.zone_count() == 1 and eh.has_zone("ok")


func test_no_damage_outside_zone() -> bool:
	var eh := EnvironmentalHazard.new()
	var far := Vector3(9999, 0, 9999)
	return eh.damage_at(far, 1.0) == 0.0 and not eh.is_in_hazard(far)


func test_damage_inside_zone() -> bool:
	var eh := EnvironmentalHazard.new()
	# toxic_dump center (100,0,100) radius 30 dps 8
	var dmg := eh.damage_at(Vector3(100, 0, 100), 1.0)
	return is_equal_approx(dmg, 8.0) and eh.is_in_hazard(Vector3(100, 0, 100))


func test_damage_scales_with_dt() -> bool:
	var eh := EnvironmentalHazard.new()
	var d1 := eh.damage_at(Vector3(100, 0, 100), 1.0)
	var d2 := eh.damage_at(Vector3(100, 0, 100), 2.0)
	return is_equal_approx(d2, d1 * 2.0)


func test_protection_reduces_damage() -> bool:
	var eh := EnvironmentalHazard.new()
	var full := eh.damage_at(Vector3(100, 0, 100), 1.0, 0.0)
	var half := eh.damage_at(Vector3(100, 0, 100), 1.0, 0.5)
	return is_equal_approx(half, full * 0.5)


func test_full_protection_zero_damage() -> bool:
	var eh := EnvironmentalHazard.new()
	return eh.damage_at(Vector3(100, 0, 100), 1.0, 1.0) == 0.0


func test_damage_uses_xz_plane() -> bool:
	var eh := EnvironmentalHazard.new()
	# Same XZ as the toxic_dump centre but 500m up -> still inside (height ignored).
	return is_equal_approx(eh.damage_at(Vector3(100, 500, 100), 1.0), 8.0)


func test_dominant_hazard_at() -> bool:
	var eh := EnvironmentalHazard.new()
	return (
		eh.dominant_hazard_at(Vector3(100, 0, 100)) == EnvironmentalHazard.Hazard.TOXIC
		and eh.dominant_hazard_at(Vector3(9999, 0, 0)) == -1
	)


func test_overlapping_zones_sum_damage() -> bool:
	var eh := (
		EnvironmentalHazard
		. new(
			[
				{"id": "a", "type": 0, "center": Vector3.ZERO, "radius": 20.0, "dps": 5.0},
				{"id": "b", "type": 2, "center": Vector3(5, 0, 0), "radius": 20.0, "dps": 7.0},
			]
		)
	)
	# (2,0,0) is inside both circles -> 5 + 7
	return is_equal_approx(eh.damage_at(Vector3(2, 0, 0), 1.0), 12.0)


func test_dominant_picks_highest_dps() -> bool:
	var eh := (
		EnvironmentalHazard
		. new(
			[
				{"id": "weak", "type": 0, "center": Vector3.ZERO, "radius": 20.0, "dps": 5.0},
				{"id": "strong", "type": 1, "center": Vector3.ZERO, "radius": 20.0, "dps": 15.0},
			]
		)
	)
	return eh.dominant_hazard_at(Vector3.ZERO) == EnvironmentalHazard.Hazard.RADIATION


func test_strongest_dps_at() -> bool:
	var eh := (
		EnvironmentalHazard
		. new(
			[
				{"id": "weak", "type": 0, "center": Vector3.ZERO, "radius": 20.0, "dps": 5.0},
				{"id": "strong", "type": 1, "center": Vector3.ZERO, "radius": 20.0, "dps": 15.0},
			]
		)
	)
	return (
		is_equal_approx(eh.strongest_dps_at(Vector3.ZERO), 15.0)
		and eh.strongest_dps_at(Vector3(9999, 0, 0)) == 0.0
	)


func test_add_transient_creates_zone() -> bool:
	var eh := EnvironmentalHazard.new()
	var ok := eh.add_transient(
		"gas", EnvironmentalHazard.Hazard.TOXIC, Vector3.ZERO, 15.0, 10.0, 5.0
	)
	return ok and eh.has_zone("gas") and is_equal_approx(eh.damage_at(Vector3.ZERO, 1.0), 10.0)


func test_add_transient_duplicate_and_invalid_fail() -> bool:
	var eh := EnvironmentalHazard.new()
	var dup := eh.add_transient("toxic_dump", 0, Vector3.ZERO, 10.0, 5.0, 5.0)
	var bad_radius := eh.add_transient("x", 0, Vector3.ZERO, -1.0, 5.0, 5.0)
	var bad_duration := eh.add_transient("y", 0, Vector3.ZERO, 10.0, 5.0, 0.0)
	return dup == false and bad_radius == false and bad_duration == false


func test_tick_expires_transient() -> bool:
	var eh := EnvironmentalHazard.new()
	eh.add_transient("gas", 0, Vector3.ZERO, 15.0, 10.0, 5.0)  # 5s lifetime
	var expired := eh.tick(6.0)
	return "gas" in expired and not eh.has_zone("gas")


func test_tick_before_duration_keeps() -> bool:
	var eh := EnvironmentalHazard.new()
	eh.add_transient("gas", 0, Vector3.ZERO, 15.0, 10.0, 5.0)
	var expired := eh.tick(2.0)
	return expired.size() == 0 and eh.has_zone("gas")


func test_tick_does_not_expire_permanent() -> bool:
	var eh := EnvironmentalHazard.new()
	var before := eh.zone_count()
	var expired := eh.tick(100000.0)  # permanent zones survive any span
	return expired.size() == 0 and eh.zone_count() == before


func test_tick_nonpositive_noop() -> bool:
	var eh := EnvironmentalHazard.new()
	eh.add_transient("gas", 0, Vector3.ZERO, 15.0, 10.0, 5.0)
	var a := eh.tick(0.0)
	var b := eh.tick(-3.0)
	return a.size() == 0 and b.size() == 0 and eh.has_zone("gas")


func test_remove_zone() -> bool:
	var eh := EnvironmentalHazard.new()
	var removed := eh.remove_zone("toxic_dump")
	return removed and not eh.has_zone("toxic_dump") and not eh.remove_zone("nope")


func test_damage_at_nonpositive_dt_zero() -> bool:
	var eh := EnvironmentalHazard.new()
	var inside := Vector3(100, 0, 100)
	return eh.damage_at(inside, 0.0) == 0.0 and eh.damage_at(inside, -1.0) == 0.0


func test_protection_out_of_range_clamped() -> bool:
	# protection > 1 must clamp to 1 (zero damage), not go negative (healing); < 0 clamps to 0.
	var eh := EnvironmentalHazard.new()
	var over := eh.damage_at(Vector3(100, 0, 100), 1.0, 1.5)
	var under := eh.damage_at(Vector3(100, 0, 100), 1.0, -0.5)
	return over == 0.0 and is_equal_approx(under, 8.0)


func test_radius_boundary_is_inside() -> bool:
	var eh := EnvironmentalHazard.new(
		[{"id": "z", "type": 0, "center": Vector3.ZERO, "radius": 10.0, "dps": 4.0}]
	)
	# A point exactly `radius` away is covered (<=).
	return (
		eh.is_in_hazard(Vector3(10, 0, 0))
		and is_equal_approx(eh.damage_at(Vector3(10, 0, 0), 1.0), 4.0)
	)


func test_multiple_transients_expire_together() -> bool:
	var eh := EnvironmentalHazard.new(
		[{"id": "perm", "type": 0, "center": Vector3.ZERO, "radius": 5.0, "dps": 1.0}]
	)
	eh.add_transient("g1", 0, Vector3.ZERO, 5.0, 3.0, 4.0)
	eh.add_transient("g2", 0, Vector3.ZERO, 5.0, 3.0, 4.0)
	var expired := eh.tick(5.0)
	return (
		expired.size() == 2
		and not eh.has_zone("g1")
		and not eh.has_zone("g2")
		and eh.has_zone("perm")
	)  # permanent survives
