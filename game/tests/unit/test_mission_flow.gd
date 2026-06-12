extends RefCounted
## Unit tests for MissionFlow (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Pure sequencing + fail math — no scene.


func _objectives(done_flags: Array) -> Array:
	# Build a 3-step objective list with the given done flags.
	var ids := ["reach_a", "reach_b", "survive"]
	var texts := ["Reach the docks", "Reach the lighthouse", "Survive 30s"]
	var out := []
	for i in 3:
		out.append({"id": ids[i], "text": texts[i], "done": done_flags[i]})
	return out


# --- current sequencing ---------------------------------------------------


func test_current_index_is_first_open() -> bool:
	return MissionFlow.current_index(_objectives([true, false, false])) == 1


func test_current_index_none_when_all_done() -> bool:
	return MissionFlow.current_index(_objectives([true, true, true])) == MissionFlow.NO_INDEX


func test_current_index_none_when_empty() -> bool:
	return MissionFlow.current_index([]) == MissionFlow.NO_INDEX


func test_current_returns_objective_dict() -> bool:
	return MissionFlow.current(_objectives([true, false, false]))["id"] == "reach_b"


func test_current_text_first_open() -> bool:
	return MissionFlow.current_text(_objectives([false, false, false])) == "Reach the docks"


func test_current_text_empty_when_done() -> bool:
	return MissionFlow.current_text(_objectives([true, true, true])) == ""


func test_done_count() -> bool:
	return MissionFlow.done_count(_objectives([true, false, true])) == 2


# --- hud line -------------------------------------------------------------


func test_hud_line_shows_current_objective() -> bool:
	# One done → working on objective 2 of 3.
	return (
		MissionFlow.hud_line("HEIST", _objectives([true, false, false]))
		== "HEIST — Reach the lighthouse (2/3)"
	)


func test_hud_line_complete() -> bool:
	return (
		MissionFlow.hud_line("HEIST", _objectives([true, true, true])) == "HEIST — complete (3/3)"
	)


# --- fail conditions ------------------------------------------------------


func test_timed_out_true_when_clock_zero() -> bool:
	return MissionFlow.timed_out(30.0, 0.0)


func test_timed_out_false_with_time_left() -> bool:
	return not MissionFlow.timed_out(30.0, 5.0)


func test_untimed_never_times_out() -> bool:
	return not MissionFlow.timed_out(0.0, -1.0)


func test_should_fail_on_player_death() -> bool:
	return MissionFlow.should_fail(true, 0.0, 99.0)


func test_should_fail_on_timeout() -> bool:
	return MissionFlow.should_fail(false, 30.0, 0.0)


func test_should_not_fail_when_alive_and_timed() -> bool:
	return not MissionFlow.should_fail(false, 30.0, 12.0)


# --- waypoints ------------------------------------------------------------


func test_current_waypoint_maps_current_objective() -> bool:
	var wp := {"reach_a": Vector3(10, 0, 5), "reach_b": Vector3(40, 0, -8)}
	return (
		MissionFlow.current_waypoint(_objectives([true, false, false]), wp, Vector3.ZERO)
		== Vector3(40, 0, -8)
	)


func test_current_waypoint_fallback_when_unmapped() -> bool:
	var fallback := Vector3(1, 2, 3)
	return (
		MissionFlow.current_waypoint(_objectives([false, false, false]), {}, fallback) == fallback
	)


func test_current_waypoint_fallback_when_complete() -> bool:
	var fallback := Vector3(7, 7, 7)
	var wp := {"reach_a": Vector3(10, 0, 5)}
	return MissionFlow.current_waypoint(_objectives([true, true, true]), wp, fallback) == fallback
