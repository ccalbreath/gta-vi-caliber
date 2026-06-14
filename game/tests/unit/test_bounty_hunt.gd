extends RefCounted
## Unit tests for BountyHunt (see tests/run_tests.gd for the runner contract: test_* methods
## return true to pass).
##
## Covers the default roster, malformed drops, an easy fugitive caught at a low combat rating, a
## tough one escaping until the rating meets their difficulty (the skill gate), no re-catch, the
## open-count, and the save round-trip.


func test_default_roster_loaded() -> bool:
	var b := BountyHunt.new()
	return b.fugitive_count() == 4 and b.has_fugitive("petty_thief") and b.open_count() == 4


func test_malformed_dropped() -> bool:
	var b := (
		BountyHunt
		. new(
			[
				{"id": "a", "bounty": 100, "difficulty": 0.5},
				{"id": "", "bounty": 100},  # empty id
				{"id": "no_bounty"},  # missing bounty
				{"id": "zero", "bounty": 0},  # non-positive bounty
				{"id": "a", "bounty": 200},  # duplicate
			]
		)
	)
	return b.fugitive_count() == 1 and b.has_fugitive("a")


func test_easy_caught_at_low_rating() -> bool:
	var b := BountyHunt.new()
	var r := b.attempt("petty_thief", 0.3)  # 0.3 >= difficulty 0.2
	return bool(r["success"]) and int(r["bounty"]) == 2000 and b.is_caught("petty_thief")


func test_tough_escapes_at_low_rating() -> bool:
	var b := BountyHunt.new()
	var r := b.attempt("gang_lieutenant", 0.4)  # 0.4 < difficulty 0.75 -> outgunned
	return not bool(r["success"]) and int(r["bounty"]) == 0 and not b.is_caught("gang_lieutenant")


func test_tough_caught_at_high_rating() -> bool:
	var b := BountyHunt.new()
	var escaped := b.attempt("gang_lieutenant", 0.4)  # escapes
	var caught := b.attempt("gang_lieutenant", 1.0)  # now a better shot
	return (
		not bool(escaped["success"])
		and bool(caught["success"])
		and int(caught["bounty"]) == 15000
		and b.is_caught("gang_lieutenant")
	)


func test_caught_at_exact_difficulty() -> bool:
	# Rating exactly AT the difficulty catches them (the gate is inclusive: caught iff rating >=).
	var b := BountyHunt.new()
	var r := b.attempt("petty_thief", 0.2)  # rating == difficulty 0.2
	return bool(r["success"]) and b.is_caught("petty_thief")


func test_no_recatch() -> bool:
	var b := BountyHunt.new()
	b.attempt("petty_thief", 1.0)
	var again := b.attempt("petty_thief", 1.0)
	return not bool(again["success"]) and int(again["bounty"]) == 0


func test_unknown_fugitive() -> bool:
	var b := BountyHunt.new()
	return not bool(b.attempt("nobody", 1.0)["success"])


func test_open_count_drops_on_catch() -> bool:
	var b := BountyHunt.new()
	b.attempt("petty_thief", 1.0)
	return b.open_count() == 3


func test_save_round_trip() -> bool:
	var b := BountyHunt.new()
	b.attempt("petty_thief", 1.0)
	b.attempt("armed_robber", 1.0)
	var clone := BountyHunt.new()
	clone.from_dict(b.to_dict())
	return (
		clone.is_caught("petty_thief")
		and clone.is_caught("armed_robber")
		and not clone.is_caught("cop_killer")
	)
