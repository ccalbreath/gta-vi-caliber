extends RefCounted
## Unit tests for HeistComplication (runner contract: test_* methods return true).
##
## Covers how many fire by risk (none at 0, all at 1, mild-first ordering), and
## apply()'s compounding take cut + heat + casualties at low and max risk.


func test_none_fire_at_zero_risk() -> bool:
	var hc := HeistComplication.new()
	return hc.count_for(0.0) == 0 and hc.complications_for(0.0).is_empty()


func test_all_fire_at_max_risk() -> bool:
	var hc := HeistComplication.new()
	return hc.count_for(1.0) == hc.count() and hc.count() == 5


func test_count_scales_with_risk() -> bool:
	var hc := HeistComplication.new()
	# floor(0.4 * 5) = 2 ; floor(0.7 * 5) = 3
	return hc.count_for(0.4) == 2 and hc.count_for(0.7) == 3


func test_mild_first_ordering() -> bool:
	var hc := HeistComplication.new()
	var fired := hc.complications_for(0.4)
	return fired.size() == 2 and fired[0] == "nosy_guard" and fired[1] == "silent_alarm"


func test_apply_at_zero_risk_is_clean() -> bool:
	var hc := HeistComplication.new()
	var r := hc.apply(100000, 0, 0.0)
	return r["take"] == 100000 and r["heat"] == 0 and r["casualties"] == 0 and r["fired"].is_empty()


func test_apply_low_risk() -> bool:
	var hc := HeistComplication.new()
	# 2 fire: floor(100000*0.95)=95000, floor(95000*0.90)=85500; heat 1+2=3
	var r := hc.apply(100000, 0, 0.4)
	return r["take"] == 85500 and r["heat"] == 3 and r["casualties"] == 0


func test_apply_max_risk_compounds() -> bool:
	var hc := HeistComplication.new()
	# 0.95,0.90,0.85,0.80,0.70 compounded w/ floor each step -> 40698; heat 8; 1 casualty
	var r := hc.apply(100000, 0, 1.0)
	return r["take"] == 40698 and r["heat"] == 8 and r["casualties"] == 1 and r["fired"].size() == 5
