extends RefCounted
## Unit tests for MissionChain (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func _sample() -> Array:
	return [
		{"id": "intro", "title": "Welcome", "objective_defs": [], "waypoints": {}},
		{"id": "heist", "title": "The Job", "objective_defs": [], "waypoints": {}},
		{"id": "escape", "title": "Get Out", "objective_defs": [], "waypoints": {}},
	]


func test_count_matches_definitions() -> bool:
	return MissionChain.new(_sample()).count() == 3


func test_empty_chain_is_complete() -> bool:
	var chain := MissionChain.new([])
	return chain.is_campaign_complete() and is_equal_approx(chain.progress(), 1.0)


func test_starts_on_first_mission() -> bool:
	var chain := MissionChain.new(_sample())
	return chain.active_index() == 0 and chain.current_id() == "intro"


func test_complete_current_advances() -> bool:
	var chain := MissionChain.new(_sample())
	chain.complete_current()
	return chain.active_index() == 1 and chain.current_id() == "heist"


func test_completing_all_finishes_campaign() -> bool:
	var chain := MissionChain.new(_sample())
	chain.complete_current()
	chain.complete_current()
	chain.complete_current()
	return chain.is_campaign_complete() and chain.current().is_empty()


func test_overcompleting_does_not_run_past_end() -> bool:
	var chain := MissionChain.new(_sample())
	for _i in 10:
		chain.complete_current()
	return chain.active_index() == 3 and chain.is_campaign_complete()


func test_progress_ramps() -> bool:
	var chain := MissionChain.new(_sample())
	var p0 := chain.progress()
	chain.complete_current()
	var p1 := chain.progress()
	return is_equal_approx(p0, 0.0) and is_equal_approx(p1, 1.0 / 3.0)


func test_remaining_and_completed() -> bool:
	var chain := MissionChain.new(_sample())
	chain.complete_current()
	return chain.remaining() == 2 and chain.completed() == 1


func test_current_id_empty_when_done() -> bool:
	var chain := MissionChain.new([])
	return chain.current_id() == ""


func test_reset_returns_to_first() -> bool:
	var chain := MissionChain.new(_sample())
	chain.complete_current()
	chain.complete_current()
	chain.reset()
	return chain.active_index() == 0 and chain.current_id() == "intro"


func test_current_carries_definition_fields() -> bool:
	var chain := MissionChain.new(_sample())
	var mission := chain.current()
	return mission.get("title", "") == "Welcome"


func test_init_copies_input_array() -> bool:
	var defs := _sample()
	var chain := MissionChain.new(defs)
	defs.clear()
	return chain.count() == 3
