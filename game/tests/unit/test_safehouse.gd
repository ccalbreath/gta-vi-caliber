extends RefCounted
## Unit tests for Safehouse (runner contract: test_* methods return true).
##
## Covers acquire (first becomes active) + dedupe, set_active, rest heat/heal
## (and the no-safehouse no-op), stash deposit/withdraw bounds, per-house +
## total stash, and a save round-trip.


func test_acquire_first_becomes_active() -> bool:
	var s := Safehouse.new()
	var ok := s.acquire("beach_condo", "south_beach")
	return ok and s.count() == 1 and s.active() == "beach_condo" and s.has_safehouse("beach_condo")


func test_acquire_dedupe() -> bool:
	var s := Safehouse.new()
	s.acquire("a", "downtown")
	return s.acquire("a", "wynwood") == false and s.acquire("", "x") == false and s.count() == 1


func test_set_active() -> bool:
	var s := Safehouse.new()
	s.acquire("a", "downtown")
	s.acquire("b", "wynwood")  # active stays "a"
	return (
		s.active() == "a"
		and s.set_active("b")
		and s.active() == "b"
		and s.set_active("ghost") == false
	)


func test_rest_cools_and_heals() -> bool:
	var s := Safehouse.new()
	s.acquire("a", "downtown")
	var r := s.rest(4.0)  # 4 * 1.5 = 6 heat, 4 * 20 = 80 hp
	var cooled: float = r["heat_cooled"]
	var healed: float = r["health_restored"]
	return absf(cooled - 6.0) < 0.0001 and absf(healed - 80.0) < 0.0001


func test_rest_without_safehouse_is_noop() -> bool:
	var s := Safehouse.new()
	var r := s.rest(8.0)
	return r["heat_cooled"] == 0.0 and r["health_restored"] == 0.0


func test_stash_deposit_withdraw() -> bool:
	var s := Safehouse.new()
	s.acquire("a", "downtown")
	s.stash(5000)
	s.stash(1500)
	var w := s.withdraw(2000)
	return s.stash_balance("a") == 4500 and w == 2000


func test_withdraw_bounded() -> bool:
	var s := Safehouse.new()
	s.acquire("a", "downtown")
	s.stash(1000)
	var w := s.withdraw(9999)  # only 1000 there
	return w == 1000 and s.stash_balance("a") == 0


func test_total_stashed_across_houses() -> bool:
	var s := Safehouse.new()
	s.acquire("a", "downtown")
	s.stash(1000)  # into active "a"
	s.acquire("b", "wynwood")
	s.set_active("b")
	s.stash(2500)  # into "b"
	return s.total_stashed() == 3500 and s.stash_balance("b") == 2500


func test_save_round_trip() -> bool:
	var a := Safehouse.new()
	a.acquire("a", "downtown")
	a.acquire("b", "wynwood")
	a.set_active("b")
	a.stash(7777)
	var b := Safehouse.new()
	b.from_dict(a.to_dict())
	return (
		b.count() == 2
		and b.active() == "b"
		and b.stash_balance("b") == 7777
		and b.district_of("a") == "downtown"
	)
