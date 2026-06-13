extends RefCounted
## Unit tests for FriendCircle (runner contract: test_* methods return true).
##
## Covers befriend validation + dedupe, the acquaintance start, hangout gains and
## slight losses (with bounds), tiers, the perk unlock at CLOSE, perk lookup,
## best_friend, idle decay (floored at 0), unknown-friend no-ops, and a save
## round-trip.


func test_befriend_and_start() -> bool:
	var fc := FriendCircle.new()
	var ok := fc.befriend("roman", "Roman", "wheels")
	return (
		ok
		and fc.circle_size() == 1
		and absf(fc.rapport_of("roman") - 20.0) < 0.0001
		and fc.tier_of("roman") == "acquaintance"
	)


func test_befriend_rejects_bad_and_dupes() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("roman", "Roman")
	return (
		fc.befriend("roman", "Other") == false
		and fc.befriend("", "x") == false
		and fc.circle_size() == 1
	)


func test_hangout_raises_rapport() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("lamar", "Lamar")
	var r := fc.hang_out("lamar", 1.0)  # 20 + 15 -> 35
	return absf(r - 35.0) < 0.0001 and fc.tier_of("lamar") == "friend"


func test_hangout_quality_scales() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("lamar", "Lamar")
	var r := fc.hang_out("lamar", 0.5)  # 20 + 7.5 -> 27.5
	return absf(r - 27.5) < 0.0001


func test_perk_unlocks_at_close() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("jacob", "Jacob", "guns")
	fc.hang_out("jacob", 1.0)
	fc.hang_out("jacob", 1.0)
	var locked := fc.perk_unlocked("jacob")  # 50 -> still locked
	fc.hang_out("jacob", 1.0)  # 65 -> close, unlocked
	return locked == false and fc.perk_unlocked("jacob") and fc.perk_of("jacob") == "guns"


func test_slight_lowers_and_relocks() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("jacob", "Jacob", "guns")
	fc.hang_out("jacob", 1.0)
	fc.hang_out("jacob", 1.0)
	fc.hang_out("jacob", 1.0)  # 65, close, perk unlocked
	fc.slight("jacob", 1.0)  # 65 - 25 -> 40, friend, perk relocked
	return absf(fc.rapport_of("jacob") - 40.0) < 0.0001 and fc.perk_unlocked("jacob") == false


func test_rapport_bounds() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("a", "A")
	for _i in 10:
		fc.hang_out("a", 1.0)  # clamps at 100
	fc.befriend("b", "B")
	fc.slight("b", 5.0)  # clamps at 0
	return fc.rapport_of("a") == 100.0 and fc.rapport_of("b") == 0.0


func test_decay_floors_at_zero() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("a", "A")
	fc.hang_out("a", 1.0)
	fc.hang_out("a", 1.0)
	fc.hang_out("a", 1.0)  # 65
	fc.decay(10.0)  # 65 - 1.5*10 -> 50
	var partial: bool = absf(fc.rapport_of("a") - 50.0) < 0.0001
	fc.decay(100.0)  # 50 - 150 -> floors at 0
	return partial and fc.rapport_of("a") == 0.0


func test_best_friend() -> bool:
	var fc := FriendCircle.new()
	fc.befriend("a", "A")
	fc.befriend("b", "B")
	fc.hang_out("b", 1.0)  # b ahead
	return fc.best_friend() == "b" and FriendCircle.new().best_friend() == ""


func test_unknown_friend_noops() -> bool:
	var fc := FriendCircle.new()
	return (
		fc.rapport_of("ghost") == 0.0
		and fc.hang_out("ghost", 1.0) == -1.0
		and fc.perk_unlocked("ghost") == false
	)


func test_save_round_trip() -> bool:
	var a := FriendCircle.new()
	a.befriend("roman", "Roman", "wheels")
	a.hang_out("roman", 1.0)
	a.befriend("jacob", "Jacob", "guns")
	var b := FriendCircle.new()
	b.from_dict(a.to_dict())
	return (
		b.circle_size() == 2
		and absf(b.rapport_of("roman") - a.rapport_of("roman")) < 0.0001
		and b.perk_of("jacob") == "guns"
	)
