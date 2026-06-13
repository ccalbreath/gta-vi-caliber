extends RefCounted
## Unit tests for SmugglingRun (runner contract: test_* methods return true).
##
## Covers route building, a clean run (full evasion), a chipped run (no evasion,
## progressive seizure across legs), partial evasion, a total bust, an empty route
## (nothing to interdict), and a save round-trip.


func test_build_route() -> bool:
	var s := SmugglingRun.new(100, 50)
	s.add_leg(0.5)
	s.add_leg(0.3)
	return s.leg_count() == 2 and s.cargo_units() == 100 and s.cargo_value() == 5000


func test_full_evasion_delivers_everything() -> bool:
	var s := SmugglingRun.new(100, 50)
	s.add_leg(0.5)
	s.add_leg(0.5)
	var r := s.run(1.0)  # 1 - evasion = 0 -> nothing seized
	return r["delivered"] == 100 and r["seized"] == 0 and r["interdictions"] == 0 and r["heat"] == 0


func test_no_evasion_chips_each_leg() -> bool:
	var s := SmugglingRun.new(100, 50)
	s.add_leg(0.5)
	s.add_leg(0.5)
	var r := s.run(0.0)  # leg1 seizes 50 -> 50 left; leg2 seizes 25 -> 25 left
	return (
		r["delivered"] == 25
		and r["seized"] == 75
		and r["value_delivered"] == 1250
		and r["value_seized"] == 3750
		and r["interdictions"] == 2
		and r["heat"] == 2
		and r["busted"] == false
	)


func test_partial_evasion() -> bool:
	var s := SmugglingRun.new(100, 50)
	s.add_leg(0.5)
	s.add_leg(0.5)
	# leg1 floor(100*0.5*0.5)=25 -> 75; leg2 floor(75*0.5*0.5)=18 -> 57
	var r := s.run(0.5)
	return r["delivered"] == 57 and r["seized"] == 43


func test_total_bust() -> bool:
	var s := SmugglingRun.new(100, 50)
	s.add_leg(1.0)  # seizes everything with no evasion
	var r := s.run(0.0)
	return (
		r["delivered"] == 0
		and r["seized"] == 100
		and r["busted"] == true
		and r["interdictions"] == 1
	)


func test_empty_route_delivers_all() -> bool:
	var s := SmugglingRun.new(80, 10)
	var r := s.run(0.0)
	return r["delivered"] == 80 and r["interdictions"] == 0 and r["busted"] == false


func test_save_round_trip() -> bool:
	var a := SmugglingRun.new(100, 50)
	a.add_leg(0.5)
	a.add_leg(0.3)
	var b := SmugglingRun.new()
	b.from_dict(a.to_dict())
	# same route + cargo -> identical run outcome
	var ra := a.run(0.2)
	var rb := b.run(0.2)
	return b.leg_count() == 2 and b.cargo_units() == 100 and rb["delivered"] == ra["delivered"]
