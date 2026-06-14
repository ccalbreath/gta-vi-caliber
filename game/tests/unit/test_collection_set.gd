extends RefCounted
## Unit tests for CollectionSet (see tests/run_tests.gd for the runner contract: test_*
## methods return true to pass).
##
## Covers the default roster, malformed drops, finding an item (reward + progress), the
## set-complete bonus landing only on the LAST find, re-find / unknown no-ops, and the save
## round-trip.


func test_default_roster_loaded() -> bool:
	var c := CollectionSet.new()
	return c.total() == 10 and c.found_count() == 0 and not c.is_complete()


func test_malformed_dropped() -> bool:
	var c := (
		CollectionSet
		. new(
			[
				{"id": "a", "reward": 100},
				{"id": "", "reward": 100},  # empty id
				{"reward": 100},  # missing id
				{"id": "a", "reward": 200},  # duplicate
			]
		)
	)
	return c.total() == 1 and c.has_item("a")


func test_find_pays_reward_and_progresses() -> bool:
	var c := CollectionSet.new([{"id": "a", "reward": 300}, {"id": "b", "reward": 300}])
	var r := c.find("a")
	return (
		bool(r["newly_found"])
		and int(r["reward"]) == 300
		and int(r["set_bonus"]) == 0
		and c.found_count() == 1
		and c.is_found("a")
		and not c.is_complete()
	)


func test_set_bonus_only_on_final_find() -> bool:
	var c := CollectionSet.new([{"id": "a", "reward": 10}, {"id": "b", "reward": 10}], 5000)
	var first := c.find("a")
	var last := c.find("b")  # completes the set
	return (
		int(first["set_bonus"]) == 0
		and int(last["set_bonus"]) == 5000
		and bool(last["complete"])
		and c.is_complete()
	)


func test_single_item_set_completes_immediately() -> bool:
	var c := CollectionSet.new([{"id": "only", "reward": 100}], 9000)
	var r := c.find("only")
	return (
		bool(r["newly_found"])
		and int(r["reward"]) == 100
		and int(r["set_bonus"]) == 9000
		and bool(r["complete"])
		and c.is_complete()
	)


func test_refind_is_noop() -> bool:
	var c := CollectionSet.new([{"id": "a", "reward": 300}, {"id": "b", "reward": 300}])
	c.find("a")
	var again := c.find("a")
	return not bool(again["newly_found"]) and int(again["reward"]) == 0 and c.found_count() == 1


func test_unknown_id_is_noop() -> bool:
	var c := CollectionSet.new([{"id": "a", "reward": 300}])
	var r := c.find("nope")
	return not bool(r["newly_found"]) and c.found_count() == 0


func test_progress_and_remaining() -> bool:
	var c := CollectionSet.new([{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}])
	c.find("a")
	c.find("b")
	return c.remaining() == 2 and is_equal_approx(c.progress(), 0.5)


func test_save_round_trip() -> bool:
	var c := CollectionSet.new([{"id": "a"}, {"id": "b"}, {"id": "c"}])
	c.find("a")
	c.find("c")
	var clone := CollectionSet.new([{"id": "a"}, {"id": "b"}, {"id": "c"}])
	clone.from_dict(c.to_dict())
	return clone.is_found("a") and clone.is_found("c") and not clone.is_found("b")
