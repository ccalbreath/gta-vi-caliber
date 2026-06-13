class_name TestLogicFixes3
extends GdUnitTestSuite
## Regression tests for two more bug-hunt fixes:
##   - PlayerHealthModel.tick regenerated a FULL frame the instant the regen delay
##     was crossed (should only count the slice past the delay).
##   - VehicleCondition.drive accrued wear for the FULL requested distance even
##     when the tank ran dry partway (should scale by the fuelled fraction).


func test_regen_only_counts_time_past_the_delay() -> void:
	var m := PlayerHealthModel.new(100.0, 10.0, 5.0)  # max, regen_rate, regen_delay
	m.apply(50.0)  # health 50, resets the damage timer
	m.tick(5.5)  # crosses the 5s delay; only 0.5s is past it -> +5, not +55
	assert_float(m.health).is_equal_approx(55.0, 0.0001)


func test_regen_full_rate_once_fully_past_delay() -> void:
	var m := PlayerHealthModel.new(100.0, 10.0, 5.0)
	m.apply(50.0)
	m.tick(5.5)  # health 55
	m.tick(1.0)  # fully past the delay now -> full frame's regen (+10)
	assert_float(m.health).is_equal_approx(65.0, 0.0001)


func test_vehicle_wear_only_for_fuelled_distance() -> void:
	# bike: tank 18, economy 0.0005. A 100km request needs 50 fuel >> tank, so it
	# runs dry after ~36km. Wear must reflect the 36km driven (~0.72), not clamp to
	# 1.0 as the old full-requested-distance accrual did.
	var vc := VehicleCondition.new()
	vc.drive("bike", 100000.0, 1.0)
	assert_float(vc.engine_wear_of("bike")).is_less(1.0)
	assert_bool(vc.is_out_of_fuel("bike")).is_true()
