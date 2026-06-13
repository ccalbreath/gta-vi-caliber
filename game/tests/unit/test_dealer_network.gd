extends RefCounted
## Unit tests for DealerNetwork (runner contract: test_* methods return true).
##
## Covers recruit validation + dedupe, fire, throughput totals, supply/stock, the
## bust-rate math (heat vs turf), a clean selling cycle (demand + stock bounds),
## a cycle with busts (network shrinks, heat added), and a save round-trip.


func test_recruit_and_size() -> bool:
	var n := DealerNetwork.new()
	return n.recruit("rico", "downtown") and n.network_size() == 1 and n.has_dealer("rico")


func test_recruit_rejects_bad_and_dupes() -> bool:
	var n := DealerNetwork.new()
	n.recruit("rico", "downtown")
	return (
		n.recruit("rico", "wynwood") == false  # duplicate id
		and n.recruit("", "downtown") == false  # empty id
		and n.recruit("zero", "downtown", 0) == false  # non-positive throughput
		and n.network_size() == 1
	)


func test_fire() -> bool:
	var n := DealerNetwork.new()
	n.recruit("rico", "downtown")
	return n.fire("rico") and n.network_size() == 0 and n.fire("ghost") == false


func test_throughput_total() -> bool:
	var n := DealerNetwork.new()
	n.recruit("a", "d", 10)
	n.recruit("b", "d", 15)
	return n.throughput_total() == 25


func test_supply_stock() -> bool:
	var n := DealerNetwork.new()
	n.supply(100)
	n.supply(-5)  # ignored
	n.supply(20)
	return n.product_stock() == 120


func test_bust_rate_math() -> bool:
	var n := DealerNetwork.new()
	return (
		absf(n.bust_rate(1.0, 0.0) - 0.5) < 0.0001
		and n.bust_rate(0.0, 1.0) == 0.0
		and absf(n.bust_rate(0.8, 0.2) - 0.3) < 0.0001
	)


func test_clean_cycle_sells() -> bool:
	var n := DealerNetwork.new()
	n.recruit("a", "d", 10)
	n.recruit("b", "d", 10)  # throughput 20
	n.supply(100)
	var r := n.run_cycle(1.0, 5, 0.0, 0.0)  # demand 1, price 5, no heat
	return (
		r["units_sold"] == 20
		and r["revenue"] == 100
		and r["busts"] == 0
		and r["stock_left"] == 80
		and r["network_size"] == 2
	)


func test_cycle_bounded_by_demand_then_stock() -> bool:
	var low_demand := DealerNetwork.new()
	low_demand.recruit("a", "d", 10)
	low_demand.recruit("b", "d", 10)
	low_demand.supply(100)
	var r1 := low_demand.run_cycle(0.5, 1, 0.0, 0.0)  # floor(20*0.5)=10
	var low_stock := DealerNetwork.new()
	low_stock.recruit("a", "d", 10)
	low_stock.recruit("b", "d", 10)
	low_stock.supply(5)
	var r2 := low_stock.run_cycle(1.0, 1, 0.0, 0.0)  # min(20,5)=5
	return r1["units_sold"] == 10 and r2["units_sold"] == 5 and r2["stock_left"] == 0


func test_cycle_busts_shrink_network() -> bool:
	var n := DealerNetwork.new()
	for i in 10:
		n.recruit("d%d" % i, "downtown", 10)
	n.supply(1000)
	var r := n.run_cycle(1.0, 1, 1.0, 0.0)  # heat 1, turf 0 -> bust_rate 0.5 -> 5 busts
	return (
		r["busts"] == 5
		and r["network_size"] == 5
		and r["heat_added"] == 5
		and n.network_size() == 5
	)


func test_save_round_trip() -> bool:
	var a := DealerNetwork.new()
	a.recruit("rico", "downtown", 12)
	a.recruit("mara", "wynwood", 8)
	a.supply(250)
	var b := DealerNetwork.new()
	b.from_dict(a.to_dict())
	return (
		b.network_size() == 2
		and b.has_dealer("rico")
		and b.throughput_total() == a.throughput_total()
		and b.product_stock() == 250
	)
