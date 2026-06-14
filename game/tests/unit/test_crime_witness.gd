extends RefCounted
## Unit tests for CrimeWitness (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).

# Ped-ish defaults: a 60-degree half-cone (120 total), 10m sight.
const PED_FOV: float = PI / 3.0
const PED_RANGE: float = 10.0

# --- can_witness -----------------------------------------------------------


func test_can_witness_dead_ahead() -> bool:
	# Observer at origin facing +X, crime 5m straight ahead.
	return CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(5, 0, 0), PED_RANGE, PED_FOV
	)


func test_can_witness_within_cone_edge() -> bool:
	# 45 degrees off-axis is inside a 60-degree half-cone.
	var crime := Vector3(5, 0, 5)  # 45 deg from +X
	return CrimeWitness.can_witness(Vector3.ZERO, Vector3(1, 0, 0), crime, PED_RANGE, PED_FOV)


func test_cannot_witness_behind() -> bool:
	# Crime directly behind the observer is outside any forward FOV.
	return not CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(-5, 0, 0), PED_RANGE, PED_FOV
	)


func test_cannot_witness_outside_cone() -> bool:
	# 90 degrees to the side is outside a 60-degree half-cone.
	return not CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 0, 5), PED_RANGE, PED_FOV
	)


func test_range_boundary() -> bool:
	# Dead ahead, 9.9m in range / 20m out of a 10m sight.
	var inside := CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(9.9, 0, 0), PED_RANGE, PED_FOV
	)
	var outside := CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(20, 0, 0), PED_RANGE, PED_FOV
	)
	return inside and not outside


func test_zero_facing_cannot_witness() -> bool:
	# No defined forward -> sees nothing, even point-blank.
	return not CrimeWitness.can_witness(
		Vector3.ZERO, Vector3.ZERO, Vector3(1, 0, 0), PED_RANGE, PED_FOV
	)


func test_crime_on_top_of_observer_seen() -> bool:
	# No meaningful bearing; counts as witnessed.
	return CrimeWitness.can_witness(
		Vector3(2, 0, 2), Vector3(1, 0, 0), Vector3(2, 0, 2), PED_RANGE, PED_FOV
	)


func test_cop_wider_sees_what_ped_misses() -> bool:
	# 90 deg to the side: ped (60 half-cone) misses, cop (120 half-cone) catches.
	var crime := Vector3(0, 0, 5)
	var ped_sees := CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), crime, PED_RANGE, PED_FOV
	)
	var cop_sees := CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), crime, 25.0, 2.0 * PI / 3.0
	)
	return (not ped_sees) and cop_sees


func test_ignores_vertical_offset() -> bool:
	# Crime is 5m ahead but 100m up — still witnessed (we steer on XZ).
	return CrimeWitness.can_witness(
		Vector3.ZERO, Vector3(1, 0, 0), Vector3(5, 100, 0), PED_RANGE, PED_FOV
	)


# --- count_witnesses -------------------------------------------------------


func test_count_only_those_who_see() -> bool:
	var crime := Vector3(0, 0, 0)
	var observers := [
		{"pos": Vector3(-5, 0, 0), "facing": Vector3(1, 0, 0)},  # sees (faces crime)
		{"pos": Vector3(5, 0, 0), "facing": Vector3(1, 0, 0)},  # faces away, misses
		{"pos": Vector3(0, 0, -5), "facing": Vector3(0, 0, 1)},  # sees
		{"pos": Vector3(100, 0, 0), "facing": Vector3(-1, 0, 0)},  # too far
	]
	return CrimeWitness.count_witnesses(crime, observers, PED_RANGE, PED_FOV) == 2


func test_count_empty_alley_zero() -> bool:
	return CrimeWitness.count_witnesses(Vector3.ZERO, [], PED_RANGE, PED_FOV) == 0


func test_count_skips_malformed_entries() -> bool:
	var observers := [
		"not a dict",
		{"pos": Vector3(-5, 0, 0), "facing": Vector3(1, 0, 0)},  # sees
		{"pos": Vector3(-3, 0, 0)},  # missing facing -> zero facing -> can't see
	]
	return CrimeWitness.count_witnesses(Vector3.ZERO, observers, PED_RANGE, PED_FOV) == 1


# --- heat_for_crime --------------------------------------------------------


func test_heat_zero_witnesses_is_zero() -> bool:
	return is_equal_approx(CrimeWitness.heat_for_crime(10.0, 0), 0.0)


func test_heat_one_witness() -> bool:
	# base * (1 - 0.5^1) = 10 * 0.5 = 5.0
	return is_equal_approx(CrimeWitness.heat_for_crime(10.0, 1), 5.0)


func test_heat_two_witnesses_diminishing() -> bool:
	# base * (1 - 0.5^2) = 10 * 0.75 = 7.5; more than one but less than double.
	return is_equal_approx(CrimeWitness.heat_for_crime(10.0, 2), 7.5)


func test_heat_saturates_below_base() -> bool:
	# Many witnesses approach but never reach base_heat.
	var h := CrimeWitness.heat_for_crime(10.0, 50)
	return h < 10.0 and h > 9.99


func test_heat_monotonic_increasing() -> bool:
	var h1 := CrimeWitness.heat_for_crime(10.0, 1)
	var h2 := CrimeWitness.heat_for_crime(10.0, 2)
	var h3 := CrimeWitness.heat_for_crime(10.0, 3)
	return h1 < h2 and h2 < h3 and h3 < 10.0


# --- stateful report timer -------------------------------------------------


func test_report_not_done_before_delay() -> bool:
	var r := CrimeWitness.new(3.0)
	r.tick(1.0)
	return not r.is_reported()


func test_report_progress_ramps() -> bool:
	var r := CrimeWitness.new(4.0)
	var p0 := r.progress()
	r.tick(1.0)
	var p1 := r.progress()  # 0.25
	r.tick(1.0)
	var p2 := r.progress()  # 0.5
	return is_equal_approx(p0, 0.0) and is_equal_approx(p1, 0.25) and is_equal_approx(p2, 0.5)


func test_report_completes_and_clamps() -> bool:
	# Overshooting the delay still lands exactly at reported / progress 1.0.
	var r := CrimeWitness.new(3.0)
	r.tick(10.0)
	return r.is_reported() and is_equal_approx(r.progress(), 1.0)


func test_silence_before_completion_stays_unreported() -> bool:
	var r := CrimeWitness.new(3.0)
	r.tick(1.0)
	r.silence()
	r.tick(5.0)  # more time, but the witness is gone
	return not r.is_reported() and is_equal_approx(r.progress(), 0.0)


func test_negative_delta_ignored() -> bool:
	var r := CrimeWitness.new(3.0)
	r.tick(1.0)
	r.tick(-5.0)
	return is_equal_approx(r.progress(), 1.0 / 3.0)


func test_reset_rearms() -> bool:
	var r := CrimeWitness.new(2.0)
	r.tick(2.0)
	var was_reported := r.is_reported()
	r.reset()
	return was_reported and not r.is_reported() and is_equal_approx(r.progress(), 0.0)


func test_reset_clears_silence() -> bool:
	var r := CrimeWitness.new(2.0)
	r.silence()
	r.reset()
	r.tick(2.0)
	return r.is_reported()


func test_zero_delay_reports_immediately() -> bool:
	var r := CrimeWitness.new(0.0)
	return r.is_reported() and is_equal_approx(r.progress(), 1.0)
