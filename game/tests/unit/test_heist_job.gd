extends RefCounted
## Unit tests for HeistJob (runner contract: test_* methods return true).
##
## Exercises the full heist trio through the facade: combined odds (plan risk +
## crew skill), a clean success paying the player's cut, complications eating the
## take on a risky job, a caught failure, the not-ready guard, and the zero-chance
## roll. Setup helpers build a ready smart heist and a risky loud one.


func _smart_job() -> HeistJob:
	# Smart approach, 3 preps done, a skilled crew (avg 0.7, player keeps 0.6).
	var j := HeistJob.new()
	j.plan().set_approach("smart")
	for i in 3:
		j.plan().add_prep("p%d" % i)
		j.plan().complete_prep("p%d" % i)
	j.crew().add_member("driver", 0.8, 0.2)
	j.crew().add_member("hacker", 0.6, 0.2)
	return j


func test_not_ready_does_not_launch() -> bool:
	var j := HeistJob.new()  # no approach chosen
	var r := j.resolve(true, 100000, 0)
	return r["launched"] == false and r["take"] == 0 and j.success_chance() == 0.0


func test_success_chance_combines_plan_and_crew() -> bool:
	# smart risk 0.25 - 3*0.08 - 0.7*0.3 = -0.2 -> floor 0.05 -> chance 0.95
	return absf(_smart_job().success_chance() - 0.95) < 0.0001


func test_success_pays_player_cut() -> bool:
	var r := _smart_job().resolve(true, 100000, 0)
	# gross = 100000 * 1.25 * 1.15 = 143750 ; risk 0.05 -> no complications
	# player take = floor(143750 * 0.6) = 86250
	return (
		r["success"] == true
		and r["gross"] == 143750
		and r["take"] == 86250
		and r["heat"] == 0
		and r["casualties"] == 0
	)


func test_failure_is_caught() -> bool:
	var r := _smart_job().resolve(false, 100000, 2)
	return r["launched"] == true and r["success"] == false and r["take"] == 0 and r["heat"] == 7


func test_complications_eat_take_on_risky_job() -> bool:
	var j := HeistJob.new()
	j.plan().set_approach("loud")  # mult 1.0, min_prep 1
	j.plan().add_prep("a")
	j.plan().complete_prep("a")
	j.crew().add_member("muscle", 0.0, 0.0)  # crew_skill 0, player keeps all
	var r := j.resolve(true, 100000, 0)
	# risk 0.5 - 0.08 = 0.42 -> 2 complications; take 100000*1.05=105000
	# floor(105000*0.95)=99750 ; floor(99750*0.90)=89775 ; heat 1+2=3
	return r["gross"] == 89775 and r["take"] == 89775 and r["heat"] == 3


func test_roll_zero_chance_never_succeeds() -> bool:
	var j := HeistJob.new()  # not ready -> success_chance 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return j.roll(rng) == false  # randf() < 0 is never true
