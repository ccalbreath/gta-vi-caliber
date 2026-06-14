extends RefCounted
## Unit tests for VehicleHandling — the arcade grip/drift/handbrake feel layer
## (see tests/run_tests.gd for the runner contract: test_* methods return true
## to pass). Pure deterministic math; no nodes, no asserts, is_equal_approx.

# --- slip_angle ---------------------------------------------------------------


func test_slip_angle_zero_driving_straight() -> bool:
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.slip_angle(vel, fwd), 0.0)


func test_slip_angle_grows_when_velocity_diverges() -> bool:
	# Travelling 45° off the nose: velocity points -Z and +X, car points -Z.
	var vel := Vector3(10.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.slip_angle(vel, fwd), PI / 4.0)


func test_slip_angle_sideways_is_ninety_degrees() -> bool:
	var vel := Vector3(10.0, 0.0, 0.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.slip_angle(vel, fwd), PI / 2.0)


func test_slip_angle_zero_velocity_guarded() -> bool:
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.slip_angle(Vector3.ZERO, fwd), 0.0)


func test_slip_angle_ignores_vertical() -> bool:
	# A purely vertical velocity component must not register as slip.
	var vel := Vector3(0.0, 5.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.slip_angle(vel, fwd), 0.0)


# --- drift_factor -------------------------------------------------------------


func test_drift_factor_zero_when_aligned() -> bool:
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.drift_factor(vel, fwd), 0.0)


func test_drift_factor_full_at_large_slip() -> bool:
	# 90° of slip is well past full_slip (~35°), so it saturates at 1.
	var vel := Vector3(10.0, 0.0, 0.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.drift_factor(vel, fwd), 1.0)


func test_drift_factor_partial_mid_slip() -> bool:
	# slip_angle here is PI/4 ~= 0.785; with full_slip 1.5708 that is 0.5.
	var vel := Vector3(10.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var f := VehicleHandling.drift_factor(vel, fwd, PI / 2.0)
	return is_equal_approx(f, 0.5)


# --- lateral_grip / handbrake -------------------------------------------------


func test_lateral_grip_base_passthrough() -> bool:
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.lateral_grip(vel, fwd, 0.8, 0.0), 0.8)


func test_handbrake_reduces_grip() -> bool:
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var gripped := VehicleHandling.lateral_grip(vel, fwd, 0.8, 0.0)
	var braked := VehicleHandling.lateral_grip(vel, fwd, 0.8, 1.0)
	return braked < gripped and braked >= 0.0


func test_handbrake_cut_value() -> bool:
	# base 0.8, full handbrake, cut 0.85 -> 0.8 * (1 - 0.85) = 0.12.
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.lateral_grip(vel, fwd, 0.8, 1.0, 0.85), 0.12)


func test_lateral_grip_clamped() -> bool:
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	return is_equal_approx(VehicleHandling.lateral_grip(vel, fwd, 5.0, 0.0), 1.0)


# --- apply_friction -----------------------------------------------------------


func test_apply_friction_bleeds_lateral_keeps_forward() -> bool:
	# Sliding: 3 m/s sideways (+X), 10 m/s forward (-Z). grip 1, delta 0.5 ->
	# bleed 0.5 -> lateral halves to 1.5, forward stays -10.
	var vel := Vector3(3.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var out := VehicleHandling.apply_friction(vel, fwd, 1.0, 0.5)
	return is_equal_approx(out.x, 1.5) and is_equal_approx(out.z, -10.0)


func test_apply_friction_full_grip_kills_slide_faster() -> bool:
	var vel := Vector3(4.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var high := VehicleHandling.apply_friction(vel, fwd, 1.0, 0.5)
	var low := VehicleHandling.apply_friction(vel, fwd, 0.1, 0.5)
	# More grip leaves less sideways velocity remaining.
	return absf(high.x) < absf(low.x)


func test_apply_friction_no_lateral_is_noop() -> bool:
	var vel := Vector3(0.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var out := VehicleHandling.apply_friction(vel, fwd, 1.0, 0.5)
	return is_equal_approx(out.x, 0.0) and is_equal_approx(out.z, -10.0)


func test_apply_friction_bleed_clamped_no_overshoot() -> bool:
	# grip*delta = 4 would overshoot; clamped to 1 so lateral lands exactly 0,
	# never flipping to the far side.
	var vel := Vector3(3.0, 0.0, -10.0)
	var fwd := Vector3(0.0, 0.0, -1.0)
	var out := VehicleHandling.apply_friction(vel, fwd, 8.0, 0.5)
	return is_equal_approx(out.x, 0.0) and is_equal_approx(out.z, -10.0)


func test_apply_friction_zero_velocity_guarded() -> bool:
	var fwd := Vector3(0.0, 0.0, -1.0)
	var out := VehicleHandling.apply_friction(Vector3.ZERO, fwd, 1.0, 0.5)
	return is_equal_approx(out.length(), 0.0)


# --- steer_response -----------------------------------------------------------


func test_steer_response_full_when_parked() -> bool:
	return is_equal_approx(VehicleHandling.steer_response(0.0, 0.6, 20.0), 0.6)


func test_steer_response_shrinks_with_speed() -> bool:
	var slow := VehicleHandling.steer_response(5.0, 0.6, 20.0)
	var fast := VehicleHandling.steer_response(40.0, 0.6, 20.0)
	return fast < slow and fast > 0.0


func test_steer_response_half_at_falloff_speed() -> bool:
	# At speed == falloff the denominator is 2, so authority halves.
	return is_equal_approx(VehicleHandling.steer_response(20.0, 0.6, 20.0), 0.3)


# --- speed_kmh ----------------------------------------------------------------


func test_speed_kmh_conversion() -> bool:
	return is_equal_approx(VehicleHandling.speed_kmh(Vector3(0.0, 0.0, -10.0)), 36.0)


func test_speed_kmh_ignores_vertical() -> bool:
	return is_equal_approx(VehicleHandling.speed_kmh(Vector3(0.0, 99.0, 0.0)), 0.0)


# --- DriftScorer --------------------------------------------------------------


func test_drift_scorer_accumulates_when_sliding() -> bool:
	var scorer := VehicleHandling.DriftScorer.new(100.0, 200.0, 0.2)
	scorer.tick(1.0, 1.0)
	return is_equal_approx(scorer.score, 100.0)


func test_drift_scorer_decays_when_gripping() -> bool:
	var scorer := VehicleHandling.DriftScorer.new(100.0, 200.0, 0.2)
	scorer.tick(1.0, 1.0)
	scorer.tick(0.0, 0.25)
	return is_equal_approx(scorer.score, 50.0)


func test_drift_scorer_floors_and_cashes_out() -> bool:
	var scorer := VehicleHandling.DriftScorer.new(100.0, 200.0, 0.2)
	scorer.tick(1.0, 0.5)
	var banked := scorer.cash_out()
	return is_equal_approx(banked, 50.0) and is_equal_approx(scorer.score, 0.0)
