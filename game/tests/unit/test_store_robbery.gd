extends RefCounted
## Unit tests for StoreRobbery (runner contract: test_* methods return true).
##
## Covers a hard stick-up (full take, no alarm), a soft one (partial take, alarm +
## extra heat), the threshold, the register depleting across robberies, refill
## (capped at capacity), an empty till, and a save round-trip.


func test_hard_robbery_empties_till() -> bool:
	var s := StoreRobbery.new(1000, 100)
	var r := s.rob(1.0)  # take_frac 1.0 -> 1000; intim >= 0.5 -> no alarm
	return (
		r["took"] == 1000 and r["alarm"] == false and r["heat"] == 3 and s.register_balance() == 0
	)


func test_soft_robbery_trips_alarm() -> bool:
	var s := StoreRobbery.new(1000, 100)
	var r := s.rob(0.0)  # take_frac 0.4 -> 400; alarm -> heat 3+2
	return (
		r["took"] == 400 and r["alarm"] == true and r["heat"] == 5 and s.register_balance() == 600
	)


func test_threshold_no_alarm_at_half() -> bool:
	var s := StoreRobbery.new(1000, 100)
	var r := s.rob(0.5)  # lerp(0.4,1.0,0.5)=0.7 -> 700; 0.5 not < 0.5 -> no alarm
	return r["took"] == 700 and r["alarm"] == false and r["heat"] == 3


func test_register_depletes_across_robberies() -> bool:
	var s := StoreRobbery.new(1000, 100)
	s.rob(0.5)  # takes 700 -> 300 left
	var r := s.rob(1.0)  # takes all 300
	return r["took"] == 300 and s.register_balance() == 0


func test_refill_caps_at_capacity() -> bool:
	var s := StoreRobbery.new(1000, 100)
	s.rob(1.0)  # empty
	s.refill(3.0)  # +300
	var mid := s.register_balance()
	s.refill(100.0)  # would overflow, caps at 1000
	return mid == 300 and s.register_balance() == 1000


func test_empty_till_takes_nothing() -> bool:
	var s := StoreRobbery.new(0, 0)
	var r := s.rob(1.0)
	return r["took"] == 0 and r["heat"] == 3  # still an armed robbery


func test_save_round_trip() -> bool:
	var a := StoreRobbery.new(1000, 100)
	a.rob(0.5)  # 300 left
	var b := StoreRobbery.new()
	b.from_dict(a.to_dict())
	return b.register_balance() == 300 and b.till_capacity() == 1000
