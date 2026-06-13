extends RefCounted
## Unit tests for MoneyLaundering (runner contract: test_* methods return true).
##
## Covers front validation, dirty intake, the laundering cut + capacity/balance
## bounds, unknown-front rejection, per-cycle capacity reset on tick(), suspicion
## rise + flagging, suspicion cooling, audit seizure (flagged vs not), and a save
## round-trip.


func test_default_fronts_loaded() -> bool:
	var ml := MoneyLaundering.new()
	return ml.front_count() == 3 and ml.has_front("laundromat") and ml.has_front("marina")


func test_malformed_fronts_dropped() -> bool:
	var ml := (
		MoneyLaundering
		. new(
			[
				{"id": "ok", "name": "OK", "capacity": 1000, "cut": 0.1},
				{"id": "", "capacity": 1000, "cut": 0.1},  # empty id
				{"capacity": 1000, "cut": 0.1},  # no id
				{"id": "bad", "capacity": 0, "cut": 0.1},  # non-positive capacity
				{"id": "toohigh", "capacity": 1000, "cut": 1.0},  # cut >= 1
				{"id": "neg", "capacity": 1000, "cut": -0.2},  # cut < 0
				{"id": "ok", "capacity": 50, "cut": 0.2},  # duplicate id
			]
		)
	)
	return ml.front_count() == 1 and ml.has_front("ok")


func test_add_dirty_accumulates_and_ignores_nonpositive() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(1000)
	ml.add_dirty(500)
	ml.add_dirty(-9999)
	ml.add_dirty(0)
	return ml.dirty_balance() == 1500


func test_launder_takes_cut() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(1000)
	var r := ml.launder("laundromat", 1000)  # cut 0.10
	return (
		r["success"]
		and r["routed"] == 1000
		and r["clean"] == 900
		and r["fee"] == 100
		and ml.dirty_balance() == 0
		and ml.clean_laundered_total() == 900
	)


func test_launder_bounded_by_capacity() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(5000)
	var r := ml.launder("laundromat", 5000)  # capacity 2000
	return (
		r["routed"] == 2000
		and ml.dirty_balance() == 3000
		and ml.capacity_remaining("laundromat") == 0
	)


func test_launder_bounded_by_dirty_balance() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(500)
	var r := ml.launder("laundromat", 2000)
	return r["routed"] == 500 and ml.dirty_balance() == 0


func test_launder_unknown_front_fails() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(1000)
	var r := ml.launder("nope", 500)
	return r["success"] == false and ml.dirty_balance() == 1000


func test_capacity_resets_on_tick() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(5000)
	ml.launder("laundromat", 2000)
	var before: int = ml.capacity_remaining("laundromat")
	ml.tick()
	return before == 0 and ml.capacity_remaining("laundromat") == 2000


func test_suspicion_rises_and_flags() -> bool:
	var ml := MoneyLaundering.new([{"id": "big", "name": "Big", "capacity": 100000, "cut": 0.2}])
	ml.add_dirty(100000)
	ml.launder("big", 40000)  # 40000 / 50000 = 0.8 suspicion
	return ml.is_flagged() and ml.suspicion_level() >= 0.7


func test_tick_cools_suspicion() -> bool:
	var ml := MoneyLaundering.new([{"id": "big", "name": "Big", "capacity": 100000, "cut": 0.2}])
	ml.add_dirty(100000)
	ml.launder("big", 40000)  # suspicion 0.8 (still flagged after one tick)
	ml.tick()  # -0.06 -> 0.74
	var cooled_once: bool = absf(ml.suspicion_level() - 0.74) < 0.0001
	ml.tick(3)  # 0.74 - 0.18 -> 0.56, drops below the 0.7 flag threshold
	return (
		cooled_once
		and ml.suspicion_level() < MoneyLaundering.AUDIT_THRESHOLD
		and not ml.is_flagged()
	)


func test_audit_seizes_when_flagged() -> bool:
	var ml := MoneyLaundering.new([{"id": "big", "name": "Big", "capacity": 100000, "cut": 0.2}])
	ml.add_dirty(100000)
	ml.launder("big", 40000)  # dirty 60000, flagged
	var r := ml.audit()  # seize 40% of 60000 = 24000
	return (
		r["flagged"] == true
		and r["seized"] == 24000
		and ml.dirty_balance() == 36000
		and absf(ml.suspicion_level() - MoneyLaundering.POST_AUDIT_SUSPICION) < 0.0001
	)


func test_audit_noop_when_not_flagged() -> bool:
	var ml := MoneyLaundering.new()
	ml.add_dirty(10000)
	ml.launder("laundromat", 1000)  # suspicion tiny, not flagged
	var r := ml.audit()
	return r["seized"] == 0 and r["flagged"] == false and ml.dirty_balance() == 9000


func test_save_round_trip() -> bool:
	var a := MoneyLaundering.new()
	a.add_dirty(10000)
	a.launder("laundromat", 1500)  # dirty 8500, used 1500, clean 1350
	var b := MoneyLaundering.new()
	b.from_dict(a.to_dict())
	return (
		b.dirty_balance() == a.dirty_balance()
		and absf(b.suspicion_level() - a.suspicion_level()) < 0.0001
		and b.clean_laundered_total() == a.clean_laundered_total()
		and b.capacity_remaining("laundromat") == a.capacity_remaining("laundromat")
	)
