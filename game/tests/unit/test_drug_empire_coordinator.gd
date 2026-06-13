extends RefCounted
## Unit tests for DrugEmpireCoordinator (runner contract: test_* methods return
## true). Drives the pure run_day() core on an orphan node (no scene tree), so it
## exercises the full Lab→Dealer→Laundering vertical end to end.
##
## Defaults under test: batch_size 20, cook_per_day 60 (a batch finishes same day),
## one dealer @ throughput 20. At demand 0.8: cook 20 → supply 20 → sell
## floor(20*0.8)=16 @ $40 = $640 dirty → launder via marina (25% cut) →
## floor(640*0.75)=$480 clean.


func test_packages_the_three_systems() -> bool:
	var c := DrugEmpireCoordinator.new()
	var ok: bool = (
		c.lab() is DrugLab and c.dealer() is DealerNetwork and c.laundering() is MoneyLaundering
	)
	c.free()
	return ok


func test_run_day_runs_the_vertical() -> bool:
	var c := DrugEmpireCoordinator.new()
	c.dealer().recruit("rico", "downtown", 20)
	var d := c.run_day(0.8, 40, 0.0, 0.5)
	var ok: bool = (
		d["produced"] == 20
		and d["sold"] == 16
		and d["revenue"] == 640
		and d["clean_earned"] == 480
		and d["dirty_left"] == 0
	)
	c.free()
	return ok


func test_no_dealers_no_sales() -> bool:
	var c := DrugEmpireCoordinator.new()
	var d := c.run_day(0.8, 40, 0.0, 0.5)  # lab still produces, but nobody to move it
	var ok: bool = (
		d["produced"] == 20 and d["sold"] == 0 and d["revenue"] == 0 and d["clean_earned"] == 0
	)
	c.free()
	return ok


func test_multiple_days_accumulate() -> bool:
	var c := DrugEmpireCoordinator.new()
	c.dealer().recruit("rico", "downtown", 20)
	var total := 0
	for _i in 3:
		total += int(c.run_day(0.8, 40, 0.0, 0.5)["clean_earned"])
	c.free()
	return total == 1440  # 480 * 3
