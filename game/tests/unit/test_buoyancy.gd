extends RefCounted
## Unit tests for Buoyancy — multi-probe float math. Submersion clamping, the
## depth cap, net summation, the submerged fraction and damping sign are what
## keep a boat floating level instead of sinking or launching.


func test_submersion_zero_above_water() -> bool:
	return Buoyancy.submersion(2.0, 0.0) == 0.0


func test_submersion_positive_below_water() -> bool:
	return absf(Buoyancy.submersion(-1.5, 0.0) - 1.5) < 0.001


func test_probe_force_scales_with_depth() -> bool:
	return absf(Buoyancy.probe_force(0.5, 10.0) - 5.0) < 0.001


func test_probe_force_caps_at_max_depth() -> bool:
	# 5 m deep but capped at 2 m -> 2 * 10.
	return absf(Buoyancy.probe_force(5.0, 10.0, 2.0) - 20.0) < 0.001


func test_net_force_sums_probes() -> bool:
	return absf(Buoyancy.net_force([0.5, 1.0, 0.0], 10.0) - 15.0) < 0.001


func test_submerged_fraction() -> bool:
	return absf(Buoyancy.submerged_fraction([1.0, 0.0, 2.0, 0.0]) - 0.5) < 0.001


func test_submerged_fraction_empty_is_zero() -> bool:
	return Buoyancy.submerged_fraction([]) == 0.0


func test_vertical_drag_opposes_motion() -> bool:
	# Rising (vy > 0) while fully submerged -> downward (negative) drag.
	return Buoyancy.vertical_drag(3.0, 1.0, 2.0) < 0.0


func test_vertical_drag_scales_with_submersion() -> bool:
	var full := Buoyancy.vertical_drag(2.0, 1.0, 2.0)
	var half := Buoyancy.vertical_drag(2.0, 0.5, 2.0)
	return absf(half - full * 0.5) < 0.001
