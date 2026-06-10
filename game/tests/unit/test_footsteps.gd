extends RefCounted
## Unit tests for Footsteps (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_stride_uses_walk_at_low_speed() -> bool:
	return absf(Footsteps.stride_length(5.0, 5.0, 8.5, 1.4, 2.2) - 1.4) < 0.0001


func test_stride_uses_run_at_high_speed() -> bool:
	return absf(Footsteps.stride_length(8.5, 5.0, 8.5, 1.4, 2.2) - 2.2) < 0.0001


func test_stride_interpolates_midspeed() -> bool:
	var s := Footsteps.stride_length(6.75, 5.0, 8.5, 1.4, 2.2)  # halfway
	return absf(s - 1.8) < 0.0001


func test_stride_clamps_above_run_speed() -> bool:
	return absf(Footsteps.stride_length(99.0, 5.0, 8.5, 1.4, 2.2) - 2.2) < 0.0001


func test_stride_degenerate_speeds_returns_walk() -> bool:
	return absf(Footsteps.stride_length(7.0, 8.5, 8.5, 1.4, 2.2) - 1.4) < 0.0001


func test_accumulate_adds_on_floor() -> bool:
	return absf(Footsteps.accumulate(0.0, 5.0, true, 0.1) - 0.5) < 0.0001


func test_accumulate_freezes_airborne() -> bool:
	return Footsteps.accumulate(1.2, 5.0, false, 0.1) == 1.2


func test_should_step_when_stride_reached() -> bool:
	return Footsteps.should_step(1.4, 1.4) and not Footsteps.should_step(1.3, 1.4)


func test_should_step_never_with_zero_stride() -> bool:
	return not Footsteps.should_step(99.0, 0.0)


func test_consume_keeps_remainder() -> bool:
	return absf(Footsteps.consume(1.5, 1.4) - 0.1) < 0.0001


func test_consume_safe_with_zero_stride() -> bool:
	return Footsteps.consume(1.5, 0.0) == 1.5


func test_surface_maps_known_group() -> bool:
	return Footsteps.surface_for_groups(["surface_grass"]) == "grass"


func test_surface_first_match_wins() -> bool:
	return Footsteps.surface_for_groups(["surface_metal", "surface_grass"]) == "metal"


func test_surface_defaults_when_untagged() -> bool:
	return Footsteps.surface_for_groups(["player", "spawnable"]) == Footsteps.DEFAULT_SURFACE


func test_surface_defaults_when_empty() -> bool:
	return Footsteps.surface_for_groups([]) == Footsteps.DEFAULT_SURFACE
