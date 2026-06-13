extends RefCounted
## Unit tests for Fence (runner contract: test_* methods return true).
##
## Covers taking loot (dedupe/bad value), inventory totals, the hot-vs-cooled
## quote (cooling raises the price), cooling (floored at 0), selling one item,
## selling the whole stash, and a save round-trip.


func test_add_loot_and_inventory() -> bool:
	var f := Fence.new()
	var ok := f.add_loot("watch", "jewelry", 1000)
	return (
		ok
		and f.inventory_count() == 1
		and f.inventory_value() == 1000
		and absf(f.item_heat("watch") - 1.0) < 0.0001
	)


func test_add_loot_rejects_dupes_and_bad() -> bool:
	var f := Fence.new()
	f.add_loot("watch", "jewelry", 1000)
	return (
		f.add_loot("watch", "jewelry", 50) == false  # dup
		and f.add_loot("", "x", 100) == false  # empty id
		and f.add_loot("y", "x", 0) == false  # non-positive value
		and f.inventory_count() == 1
	)


func test_hot_goods_fetch_less() -> bool:
	var f := Fence.new()
	f.add_loot("watch", "jewelry", 1000)
	# hot: floor(1000 * 0.6 * (1 - 1.0*0.3)) = floor(420) = 420
	return f.fence_quote("watch") == 420


func test_cooling_raises_the_quote() -> bool:
	var f := Fence.new()
	f.add_loot("watch", "jewelry", 1000)
	f.cool(2.0)  # heat 1.0 - 0.5*2 = 0 -> floor(1000*0.6*1.0) = 600
	return absf(f.item_heat("watch")) < 0.0001 and f.fence_quote("watch") == 600


func test_partial_cool() -> bool:
	var f := Fence.new()
	f.add_loot("watch", "jewelry", 1000)
	f.cool(1.0)  # heat 0.5 -> floor(1000*0.6*0.85) = 510
	return absf(f.item_heat("watch") - 0.5) < 0.0001 and f.fence_quote("watch") == 510


func test_sell_removes_and_pays() -> bool:
	var f := Fence.new()
	f.add_loot("watch", "jewelry", 1000)
	var r := f.sell("watch")  # hot -> 420
	return r["success"] == true and r["proceeds"] == 420 and f.inventory_count() == 0


func test_sell_all() -> bool:
	var f := Fence.new()
	f.add_loot("watch", "jewelry", 1000)  # hot quote 420
	f.add_loot("ring", "jewelry", 500)  # hot quote floor(500*0.6*0.7)=210
	var total := f.sell_all()
	return total == 630 and f.inventory_count() == 0


func test_save_round_trip() -> bool:
	var a := Fence.new()
	a.add_loot("watch", "jewelry", 1000)
	a.cool(1.0)  # heat 0.5
	var b := Fence.new()
	b.from_dict(a.to_dict())
	return b.inventory_count() == 1 and b.fence_quote("watch") == a.fence_quote("watch")
