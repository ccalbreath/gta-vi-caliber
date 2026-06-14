extends RefCounted
## Unit tests for Stakeout (see tests/run_tests.gd for the runner contract: test_* methods
## return true to pass).
##
## Covers the unmarked start, marking + casing to build recon (capped), the take scaling with
## recon, a blind hit tripping the alarm, move_in being one-shot + gated on marked, ctor
## clamping, and the save round-trip. Defaults: base 30000, min 0.3, alarm-below 0.6, recon
## 0.25/day — so a blind hit nets 9000 (with alarm) and a fully cased one nets 30000 clean.


func test_starts_unmarked() -> bool:
	var s := Stakeout.new()
	return not s.is_marked() and not s.is_done() and s.recon() == 0.0 and s.projected_take() == 9000


func test_mark_begins_casing() -> bool:
	var s := Stakeout.new()
	s.mark()
	return s.is_marked() and s.recon() == 0.0


func test_case_for_builds_recon() -> bool:
	var s := Stakeout.new()
	s.mark()
	s.case_for(2.0)  # 0.25 * 2
	return is_equal_approx(s.recon(), 0.5)


func test_case_for_only_while_marked() -> bool:
	var s := Stakeout.new()
	s.case_for(3.0)  # not marked -> no recon
	return s.recon() == 0.0


func test_recon_caps_at_one() -> bool:
	var s := Stakeout.new()
	s.mark()
	s.case_for(10.0)
	return is_equal_approx(s.recon(), 1.0) and s.projected_take() == 30000


func test_move_in_scales_with_recon() -> bool:
	var s := Stakeout.new()
	s.mark()
	s.case_for(3.0)  # recon 0.75 -> 0.3 + 0.75*0.7 = 0.825
	var r := s.move_in()
	return bool(r["success"]) and int(r["take"]) == 24750 and not bool(r["alarm"]) and s.is_done()


func test_blind_hit_trips_alarm() -> bool:
	var s := Stakeout.new()
	s.mark()
	var r := s.move_in()  # recon 0 -> below alarm_below
	return int(r["take"]) == 9000 and bool(r["alarm"])


func test_move_in_unmarked_fails() -> bool:
	var s := Stakeout.new()
	var r := s.move_in()
	return not bool(r["success"]) and int(r["take"]) == 0 and not s.is_done()


func test_move_in_is_one_shot() -> bool:
	var s := Stakeout.new()
	s.mark()
	s.case_for(4.0)
	s.move_in()
	var again := s.move_in()
	return not bool(again["success"]) and int(again["take"]) == 0


func test_ctor_clamps() -> bool:
	var s := Stakeout.new(-100, 2.0, -1.0, -5.0)
	return (
		s.base_take == 0
		and s.min_fraction <= 1.0
		and s.alarm_below >= 0.0
		and s.recon_per_day == 0.0
	)


func test_alarm_boundary_is_clean() -> bool:
	# recon exactly AT alarm_below is clean (the trip is strict less-than). Same 0.6 literal on
	# both sides, so the float value is bit-identical and the comparison is stable.
	var s := Stakeout.new()
	s.from_dict({"recon": 0.6, "marked": true, "done": false})
	return not bool(s.move_in()["alarm"])


func test_save_round_trip() -> bool:
	var s := Stakeout.new()  # base 30000
	s.mark()
	s.case_for(2.0)
	var clone := Stakeout.new(99999)  # a different base — the saved one must override
	clone.from_dict(s.to_dict())
	return (
		clone.is_marked()
		and is_equal_approx(clone.recon(), s.recon())
		and not clone.is_done()
		and clone.base_take == 30000
	)
