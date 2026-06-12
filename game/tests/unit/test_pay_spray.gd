extends RefCounted
## Unit tests for PaySpray (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_can_enter_inside_radius() -> bool:
	return PaySpray.can_enter(Vector3(1, 0, 0), Vector3(0, 0, 0), 2.0)


func test_can_enter_on_radius_boundary() -> bool:
	return PaySpray.can_enter(Vector3(3, 0, 0), Vector3(0, 0, 0), 3.0)


func test_can_enter_outside_radius() -> bool:
	return not PaySpray.can_enter(Vector3(5, 0, 0), Vector3(0, 0, 0), 2.0)


func test_can_enter_negative_radius_never() -> bool:
	return not PaySpray.can_enter(Vector3(0.1, 0, 0), Vector3(0, 0, 0), -5.0)


func test_cost_scales_with_stars() -> bool:
	return PaySpray.cost_for(1, 200, 100) == 300 and PaySpray.cost_for(3, 200, 100) == 500


func test_cost_zero_at_zero_stars() -> bool:
	return PaySpray.cost_for(0, 200, 100) == 0


func test_cost_clamps_stars_to_five() -> bool:
	return PaySpray.cost_for(99, 200, 100) == 700


func test_cost_never_negative() -> bool:
	return PaySpray.cost_for(2, -1000, -50) == 0


func test_seen_entering_true_with_near_cop() -> bool:
	var police := [{"pos": Vector3(3, 0, 0)}]
	return PaySpray.is_seen_entering(Vector3(0, 0, 0), police, 5.0)


func test_seen_entering_false_when_clear() -> bool:
	var police := [{"pos": Vector3(20, 0, 0)}]
	return not PaySpray.is_seen_entering(Vector3(0, 0, 0), police, 5.0)


func test_seen_entering_false_empty_police() -> bool:
	return not PaySpray.is_seen_entering(Vector3(0, 0, 0), [], 5.0)


func test_seen_entering_ignores_malformed() -> bool:
	var police := [{"nope": 1}, {"pos": "bad"}, {"pos": Vector3(50, 0, 0)}]
	return not PaySpray.is_seen_entering(Vector3(0, 0, 0), police, 5.0)


func test_respray_starts_idle() -> bool:
	var spray := PaySpray.new(3.0)
	return is_equal_approx(spray.progress(), 0.0) and not spray.is_complete()


func test_tick_before_begin_is_noop() -> bool:
	var spray := PaySpray.new(3.0)
	spray.tick(10.0)
	return is_equal_approx(spray.progress(), 0.0) and not spray.is_complete()


func test_respray_ramps() -> bool:
	var spray := PaySpray.new(4.0)
	spray.begin()
	spray.tick(1.0)
	return is_equal_approx(spray.progress(), 0.25) and not spray.is_complete()


func test_respray_completes() -> bool:
	var spray := PaySpray.new(3.0)
	spray.begin()
	spray.tick(3.0)
	return spray.is_complete() and is_equal_approx(spray.progress(), 1.0)


func test_respray_completes_once_and_holds() -> bool:
	var spray := PaySpray.new(3.0)
	spray.begin()
	spray.tick(3.0)
	spray.tick(5.0)
	return spray.is_complete() and is_equal_approx(spray.progress(), 1.0)


func test_cancel_aborts() -> bool:
	var spray := PaySpray.new(3.0)
	spray.begin()
	spray.tick(2.0)
	spray.cancel()
	return not spray.is_complete() and is_equal_approx(spray.progress(), 0.0)


func test_reset_returns_to_idle() -> bool:
	var spray := PaySpray.new(3.0)
	spray.begin()
	spray.tick(3.0)
	spray.reset()
	return not spray.is_complete() and is_equal_approx(spray.progress(), 0.0)


func test_tick_ignores_negative_delta() -> bool:
	var spray := PaySpray.new(3.0)
	spray.begin()
	spray.tick(-5.0)
	return is_equal_approx(spray.progress(), 0.0)


func test_resolve_success_deducts_and_authorizes() -> bool:
	var spray := PaySpray.new()
	var result := spray.resolve(2, 1000, false, 200, 100)
	return (
		result["allowed"]
		and result["cost"] == 400
		and result["new_balance"] == 600
		and result["reason"] == ""
	)


func test_resolve_fails_when_seen() -> bool:
	var spray := PaySpray.new()
	var result := spray.resolve(2, 1000, true, 200, 100)
	return (
		not result["allowed"]
		and result["cost"] == 0
		and result["new_balance"] == 1000
		and "seen" in result["reason"]
	)


func test_resolve_fails_when_broke() -> bool:
	var spray := PaySpray.new()
	var result := spray.resolve(3, 100, false, 200, 100)
	return (
		not result["allowed"]
		and result["new_balance"] == 100
		and "insufficient" in result["reason"]
	)


func test_resolve_fails_at_zero_stars() -> bool:
	var spray := PaySpray.new()
	var result := spray.resolve(0, 1000, false, 200, 100)
	return (
		not result["allowed"]
		and result["cost"] == 0
		and result["new_balance"] == 1000
		and "nothing" in result["reason"]
	)
