extends RefCounted
## Unit tests for HeistPlan (runner contract: test_* methods return true).
##
## Covers approach selection (valid/invalid), prep add/complete/progress, the risk
## formula (approach base − prep − crew, floored), success chance, the take with
## approach multiplier + prep padding, the launch-ready gate, and a save round-trip.


func test_starts_unplanned() -> bool:
	var p := HeistPlan.new()
	return p.approach() == "" and not p.is_ready() and p.preps_total() == 0


func test_set_approach() -> bool:
	var p := HeistPlan.new()
	return p.set_approach("smart") and p.approach() == "smart" and p.set_approach("nope") == false


func test_prep_add_complete_progress() -> bool:
	var p := HeistPlan.new()
	p.add_prep("scope")
	p.add_prep("getaway")
	var dup := p.add_prep("scope")  # duplicate
	p.complete_prep("scope")
	return (
		dup == false
		and p.preps_total() == 2
		and p.preps_done() == 1
		and absf(p.prep_progress() - 0.5) < 0.0001
		and p.complete_prep("ghost") == false
	)


func test_risk_drops_with_prep_and_crew() -> bool:
	var p := HeistPlan.new()
	p.set_approach("loud")  # base_risk 0.5
	p.add_prep("a")
	p.add_prep("b")
	p.complete_prep("a")
	p.complete_prep("b")  # 2 preps -> -0.16
	# 0.5 - 0.16 - 0.5*0.3(0.15) = 0.19
	return absf(p.risk(0.5) - 0.19) < 0.0001 and absf(p.success_chance(0.5) - 0.81) < 0.0001


func test_risk_floored() -> bool:
	var p := HeistPlan.new()
	p.set_approach("smart")  # base 0.25
	for i in 3:
		p.add_prep("p%d" % i)
		p.complete_prep("p%d" % i)  # -0.24
	# 0.25 - 0.24 - 1.0*0.3 = -0.29 -> floors at 0.05
	return absf(p.risk(1.0) - 0.05) < 0.0001


func test_unplanned_risk_is_total() -> bool:
	var p := HeistPlan.new()
	return p.risk(1.0) == 1.0 and p.success_chance(1.0) == 0.0


func test_expected_take() -> bool:
	var loud := HeistPlan.new()
	loud.set_approach("loud")  # mult 1.0, 0 preps
	var smart := HeistPlan.new()
	smart.set_approach("smart")  # mult 1.25
	for i in 3:
		smart.add_prep("p%d" % i)
		smart.complete_prep("p%d" % i)  # +0.15 take
	# smart: 100000 * 1.25 * 1.15 = 143750
	return loud.expected_take(100000) == 100000 and smart.expected_take(100000) == 143750


func test_ready_gate() -> bool:
	var p := HeistPlan.new()
	p.set_approach("stealth")  # min_prep 2
	p.add_prep("a")
	p.add_prep("b")
	p.complete_prep("a")
	var not_yet := p.is_ready()  # only 1 done
	p.complete_prep("b")
	return not_yet == false and p.is_ready()


func test_save_round_trip() -> bool:
	var a := HeistPlan.new()
	a.set_approach("smart")
	a.add_prep("scope")
	a.add_prep("gear")
	a.complete_prep("scope")
	var b := HeistPlan.new()
	b.from_dict(a.to_dict())
	return (
		b.approach() == "smart"
		and b.preps_total() == 2
		and b.preps_done() == 1
		and b.is_ready() == a.is_ready()
	)
