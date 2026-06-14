extends RefCounted
## Unit tests for ParoleTerms (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).
##
## Covers the starting state, violation accrual + streak reset, the day a violation
## happened not counting clean, revocation at the violation cap, completion at the clean
## streak, post-end no-ops, ctor clamping, and the save round-trip.


func test_starts_serving_clean() -> bool:
	var p := ParoleTerms.new()
	return p.active and p.violations == 0 and p.clean_streak == 0 and p.outcome == ""


func test_ctor_clamps_floors() -> bool:
	var p := ParoleTerms.new(0, -3)
	return p.clean_days_required == 1 and p.max_violations == 1


func test_violation_increments_and_resets_streak() -> bool:
	var p := ParoleTerms.new(5, 3)
	p.advance_day()  # clean_streak -> 1
	var r := p.record_violation()
	return (
		String(r["event"]) == "violation" and p.violations == 1 and p.clean_streak == 0 and p.active
	)


func test_violation_day_does_not_count_clean() -> bool:
	# A violation, then advancing that same day must NOT extend the clean streak.
	var p := ParoleTerms.new(5, 5)
	p.record_violation()
	var r := p.advance_day()
	return String(r["event"]) == "day" and p.clean_streak == 0


func test_clean_day_after_dirty_day_counts() -> bool:
	var p := ParoleTerms.new(5, 5)
	p.record_violation()
	p.advance_day()  # the dirty day passes, streak still 0
	p.advance_day()  # first truly clean day
	return p.clean_streak == 1


func test_revoked_at_violation_cap() -> bool:
	var p := ParoleTerms.new(5, 3)
	p.record_violation()
	p.record_violation()
	var r := p.record_violation()
	return (
		String(r["event"]) == "revoked"
		and not p.active
		and p.outcome == "revoked"
		and p.violations == 3
	)


func test_completed_at_clean_streak() -> bool:
	var p := ParoleTerms.new(3, 5)
	p.advance_day()
	p.advance_day()
	var r := p.advance_day()
	return (
		String(r["event"]) == "completed"
		and not p.active
		and p.outcome == "completed"
		and p.clean_streak == 3
	)


func test_no_op_after_revoked() -> bool:
	var p := ParoleTerms.new(5, 1)
	p.record_violation()  # revoked immediately (cap 1)
	var r1 := p.record_violation()
	var r2 := p.advance_day()
	return (
		String(r1["event"]) == "ignored"
		and String(r2["event"]) == "ignored"
		and p.outcome == "revoked"
		and p.violations == 1
	)


func test_no_op_after_completed() -> bool:
	var p := ParoleTerms.new(1, 5)
	p.advance_day()  # completed immediately (1 clean day)
	var r := p.record_violation()
	return String(r["event"]) == "ignored" and p.outcome == "completed" and p.violations == 0


func test_save_round_trip() -> bool:
	var p := ParoleTerms.new(7, 4)
	p.record_violation()
	p.advance_day()
	p.advance_day()
	var clone := ParoleTerms.new()
	clone.from_dict(p.to_dict())
	return (
		clone.clean_days_required == 7
		and clone.max_violations == 4
		and clone.violations == p.violations
		and clone.clean_streak == p.clean_streak
		and clone.active == p.active
		and clone.outcome == p.outcome
	)


func test_from_dict_rejects_non_dict() -> bool:
	var p := ParoleTerms.new(5, 3)
	p.from_dict("not a dict")
	return p.clean_days_required == 5 and p.violations == 0
