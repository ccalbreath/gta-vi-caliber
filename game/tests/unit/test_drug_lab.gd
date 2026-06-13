extends RefCounted
## Unit tests for DrugLab (runner contract: test_* methods return true).
##
## Covers purity (equipment + batch-size modifiers, clamping), start/no-double-
## cook, cooking progress + done, collecting into inventory, weighted-average
## purity across batches, raid risk (idle vs cooking + heat), street value by
## purity, withdraw bounds, and a save round-trip.


func test_purity_equipment_and_size() -> bool:
	return (
		absf(DrugLab.new(1).purity_for(10) - 0.4) < 0.0001  # 0.5 - 0.1
		and absf(DrugLab.new(3).purity_for(10) - 0.6) < 0.0001  # 0.5 + 0.2 - 0.1
		and DrugLab.new(1).purity_for(10) > DrugLab.new(1).purity_for(40)  # bigger = cuttier
		and absf(DrugLab.new(1).purity_for(50) - 0.05) < 0.0001
	)  # clamps at the floor


func test_start_no_double_cook() -> bool:
	var lab := DrugLab.new()
	return lab.start_batch(10) and lab.start_batch(10) == false and lab.start_batch(0) == false


func test_cook_progress_and_done() -> bool:
	var lab := DrugLab.new()
	lab.start_batch(10, 60.0)
	lab.cook(30.0)
	var mid: bool = absf(lab.cook_progress() - 0.5) < 0.0001 and not lab.is_batch_done()
	lab.cook(60.0)  # caps at 1.0
	return mid and lab.cook_progress() == 1.0 and lab.is_batch_done()


func test_collect_banks_inventory() -> bool:
	var lab := DrugLab.new()
	var early := lab.collect()  # nothing cooking
	lab.start_batch(10, 60.0)
	lab.cook(60.0)
	var got := lab.collect()  # 10 units @ purity 0.4
	return (
		early["units"] == 0
		and got["units"] == 10
		and absf(got["purity"] - 0.4) < 0.0001
		and lab.inventory() == 10
		and not lab.is_cooking()
	)


func test_inventory_purity_weighted() -> bool:
	var lab := DrugLab.new()
	lab.start_batch(10, 60.0)
	lab.cook(60.0)
	lab.collect()  # 10 @ 0.4
	lab.start_batch(40, 60.0)
	lab.cook(60.0)
	lab.collect()  # 40 @ 0.1 -> combined (10*0.4 + 40*0.1)/50 = 0.16
	return lab.inventory() == 50 and absf(lab.inventory_purity() - 0.16) < 0.0001


func test_raid_risk() -> bool:
	var lab := DrugLab.new()
	var idle: bool = lab.raid_risk(1.0) == 0.0
	lab.start_batch(20, 60.0)
	# base 0.05 + 20*0.005 + 0.5*0.4 = 0.05 + 0.1 + 0.2 = 0.35
	return idle and absf(lab.raid_risk(0.5) - 0.35) < 0.0001


func test_street_value_by_purity() -> bool:
	var lab := DrugLab.new()
	return (
		lab.street_value_per_unit(100, 0.5) == 100  # 100 * 1.0
		and lab.street_value_per_unit(100, 1.0) == 150  # 100 * 1.5
		and lab.street_value_per_unit(100, 0.0) == 50
	)  # 100 * 0.5


func test_withdraw_bounds() -> bool:
	var lab := DrugLab.new()
	lab.start_batch(10, 60.0)
	lab.cook(60.0)
	lab.collect()  # inventory 10
	var a := lab.withdraw(6)
	var b := lab.withdraw(100)  # only 4 left
	return a == 6 and b == 4 and lab.inventory() == 0 and lab.inventory_purity() == 0.0


func test_save_round_trip() -> bool:
	var a := DrugLab.new(2)
	a.start_batch(15, 90.0)
	a.cook(45.0)  # mid-cook
	var b := DrugLab.new()
	b.from_dict(a.to_dict())
	return (
		b.equipment_tier() == 2
		and b.is_cooking() == a.is_cooking()
		and absf(b.cook_progress() - a.cook_progress()) < 0.0001
	)
