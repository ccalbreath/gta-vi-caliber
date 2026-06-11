extends RefCounted
## Unit tests for Traction (see tests/run_tests.gd: test_* methods return true to
## pass). Reference figures: ~165 kg over a driven axle, sticky street tyre at
## mu 1.6, 9.81 m/s² gravity.

const MASS := 165.0
const GRAVITY := 9.81
const MU := 1.6

# --- normal_load -------------------------------------------------------------


func test_load_is_weight_without_downforce() -> bool:
	return is_equal_approx(Traction.normal_load(MASS, GRAVITY, 0.0), MASS * GRAVITY)


func test_downforce_adds_load() -> bool:
	var base := Traction.normal_load(MASS, GRAVITY, 0.0)
	var pressed := Traction.normal_load(MASS, GRAVITY, 500.0)
	return is_equal_approx(pressed, base + 500.0)


func test_load_never_negative() -> bool:
	return Traction.normal_load(MASS, GRAVITY, -100000.0) >= 0.0


# --- grip_limit --------------------------------------------------------------


func test_grip_is_mu_times_load() -> bool:
	return is_equal_approx(Traction.grip_limit(1000.0, MU), 1600.0)


func test_grip_zero_without_load() -> bool:
	return is_equal_approx(Traction.grip_limit(0.0, MU), 0.0)


func test_grip_scales_with_load() -> bool:
	var light := Traction.grip_limit(1000.0, MU)
	var heavy := Traction.grip_limit(2000.0, MU)
	return is_equal_approx(heavy, light * 2.0)


# --- longitudinal_grip (friction circle) -------------------------------------


func test_full_long_grip_when_not_cornering() -> bool:
	return is_equal_approx(Traction.longitudinal_grip(2000.0, 0.0), 2000.0)


func test_cornering_eats_into_long_grip() -> bool:
	var straight := Traction.longitudinal_grip(2000.0, 0.0)
	var cornering := Traction.longitudinal_grip(2000.0, 1200.0)
	return cornering < straight and cornering > 0.0


func test_friction_circle_identity() -> bool:
	# long² + lat² == grip² while inside the circle.
	var grip := 2000.0
	var lateral := 1200.0
	var longitudinal := Traction.longitudinal_grip(grip, lateral)
	return is_equal_approx(longitudinal * longitudinal + lateral * lateral, grip * grip)


func test_no_long_grip_when_lateral_saturates() -> bool:
	return is_equal_approx(Traction.longitudinal_grip(2000.0, 2500.0), 0.0)


func test_long_grip_zero_at_exact_limit() -> bool:
	return is_equal_approx(Traction.longitudinal_grip(2000.0, 2000.0), 0.0)


# --- traction_scale ----------------------------------------------------------


func test_scale_is_one_within_grip() -> bool:
	return is_equal_approx(Traction.traction_scale(1500.0, 2000.0), 1.0)


func test_scale_limits_excess_demand() -> bool:
	# Demand 4000 N against 2000 N grip → can only deliver half.
	return is_equal_approx(Traction.traction_scale(4000.0, 2000.0), 0.5)


func test_scale_handles_zero_demand() -> bool:
	return is_equal_approx(Traction.traction_scale(0.0, 2000.0), 1.0)


func test_scale_uses_demand_magnitude() -> bool:
	# Reverse (negative) demand is limited the same as forward.
	return is_equal_approx(
		Traction.traction_scale(-4000.0, 2000.0), Traction.traction_scale(4000.0, 2000.0)
	)


func test_scale_never_exceeds_one() -> bool:
	for i in range(1, 30):
		var demand := float(i) * 200.0
		var scale := Traction.traction_scale(demand, 2000.0)
		if scale > 1.0 or scale < 0.0:
			return false
	return true
