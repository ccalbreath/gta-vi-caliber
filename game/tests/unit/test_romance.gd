extends RefCounted
## Unit tests for Romance (see tests/run_tests.gd for the runner contract: test_* methods return
## true to pass).
##
## Covers the roster + malformed drops, a matched date building a lot of affection vs a mismatch
## building little, the commit milestone firing exactly once on the date that crosses COMMIT_AT,
## affection capping, unknown partners, and the save round-trip. Defaults: hit +0.4, miss +0.05,
## commit at 0.8.


func test_default_roster_loaded() -> bool:
	var r := Romance.new()
	return r.partner_count() == 3 and r.has_partner("alex") and r.liked_type_of("alex") == "dinner"


func test_malformed_dropped() -> bool:
	var r := (
		Romance
		. new(
			[
				{"id": "a", "liked_date_type": "club"},
				{"id": ""},  # empty id
				{"liked_date_type": "drive"},  # missing id
				{"id": "a", "liked_date_type": "dinner"},  # duplicate
			]
		)
	)
	return r.partner_count() == 1 and r.has_partner("a")


func test_matched_date_builds_more_than_mismatch() -> bool:
	var r := Romance.new()
	var hit := r.date("alex", "dinner")  # their favourite
	var miss := r.date("sam", "dinner")  # sam likes club
	return (
		bool(hit["hit"])
		and is_equal_approx(float(hit["gain"]), 0.4)
		and not bool(miss["hit"])
		and is_equal_approx(float(miss["gain"]), 0.05)
	)


func test_commit_fires_once_on_crossing() -> bool:
	var r := Romance.new()
	var d1 := r.date("alex", "dinner")  # 0.4
	var d2 := r.date("alex", "dinner")  # 0.8 -> commits
	var d3 := r.date("alex", "dinner")  # already committed
	return (
		not bool(d1["committed"])
		and bool(d2["committed"])
		and not bool(d3["committed"])
		and r.is_committed("alex")
	)


func test_affection_caps_at_one() -> bool:
	var r := Romance.new()
	for _i in 10:
		r.date("alex", "dinner")
	return is_equal_approx(r.affection_of("alex"), 1.0)


func test_unknown_partner() -> bool:
	var r := Romance.new()
	var d := r.date("nobody", "dinner")
	return not bool(d["hit"]) and r.affection_of("nobody") == 0.0


func test_no_regift_after_save_load() -> bool:
	# A partner restored already committed must NOT re-fire the commit milestone on the next date
	# (was_committed is re-derived from the loaded affection, so no re-gift after a save/load).
	var r := Romance.new()
	r.date("alex", "dinner")  # 0.4
	r.date("alex", "dinner")  # 0.8 -> commits
	var clone := Romance.new()
	clone.from_dict(r.to_dict())
	var d := clone.date("alex", "dinner")  # already committed
	return not bool(d["committed"]) and clone.is_committed("alex")


func test_save_round_trip() -> bool:
	var r := Romance.new()
	r.date("alex", "dinner")
	r.date("sam", "club")
	var clone := Romance.new()
	clone.from_dict(r.to_dict())
	return (
		is_equal_approx(clone.affection_of("alex"), r.affection_of("alex"))
		and is_equal_approx(clone.affection_of("sam"), r.affection_of("sam"))
	)
