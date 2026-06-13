extends RefCounted
## Cross-system INTEGRATION test — proves the criminal-economy systems built this
## session compose into one coherent money loop, not just in isolation. Each
## system has its own unit tests; this pins the CONTRACT between them (so a future
## API change that breaks the composition fails here) and doubles as executable
## documentation of the intended "run a criminal empire" gameplay flow:
##
##   rob / cook / heist  →  dirty cash + loot  →  fence + launder  →  clean money
##                                                              →  stash in a safehouse
##
## Runner contract: test_* methods return true. All systems are pure models /
## tree-free nodes, so the whole empire runs headless.


## Three days of the drug vertical, banked clean and stashed at home.
func test_drug_vertical_to_stash() -> bool:
	var drug := DrugEmpireCoordinator.new()
	drug.dealer().recruit("rico", "downtown", 20)
	var earned := 0
	for _i in 3:
		earned += int(drug.run_day(0.8, 40, 0.0, 0.5)["clean_earned"])  # 480/day
	drug.free()

	var house := Safehouse.new()
	house.acquire("condo", "south_beach")
	house.stash(earned)
	return earned == 1440 and house.stash_balance("condo") == 1440


## A stick-up + a fenced watch, both washed through a front into clean money.
func test_robbery_and_fence_to_laundered() -> bool:
	var dirty := MoneyLaundering.new()

	var store := StoreRobbery.new(1000, 100)
	dirty.add_dirty(store.rob(1.0)["took"])  # +1000

	var fence := Fence.new()
	fence.add_loot("watch", "jewelry", 2000)
	fence.cool(2.0)  # let it cool for a better quote (2000*0.6 = 1200)
	dirty.add_dirty(fence.sell("watch")["proceeds"])  # +1200 -> 2200 dirty

	dirty.tick()
	var clean: int = dirty.launder("marina", dirty.dirty_balance())["clean"]  # floor(2200*0.75)
	return clean == 1650


## A planned heist pays the player's cut into the empire's coffers.
func test_heist_score() -> bool:
	var heist := HeistJob.new()
	heist.plan().set_approach("smart")
	for i in 3:
		heist.plan().add_prep("p%d" % i)
		heist.plan().complete_prep("p%d" % i)
	heist.crew().add_member("driver", 0.8, 0.2)
	heist.crew().add_member("hacker", 0.6, 0.2)
	var score := heist.resolve(true, 100000, 0)  # smart + skilled crew -> 86250 take
	return score["take"] == 86250


## The whole week: every earner feeds one bankroll, stashed and insured, with a
## social following on the side — the full empire composing end to end.
func test_full_empire_week() -> bool:
	var bankroll := 0

	# Drug vertical (3 days).
	var drug := DrugEmpireCoordinator.new()
	drug.dealer().recruit("rico", "downtown", 20)
	for _i in 3:
		bankroll += int(drug.run_day(0.8, 40, 0.0, 0.5)["clean_earned"])  # 1440
	drug.free()

	# Robbery + fence, laundered.
	var dirty := MoneyLaundering.new()
	var store := StoreRobbery.new(1000, 100)
	dirty.add_dirty(store.rob(1.0)["took"])
	var fence := Fence.new()
	fence.add_loot("watch", "jewelry", 2000)
	fence.cool(2.0)
	dirty.add_dirty(fence.sell("watch")["proceeds"])
	dirty.tick()
	bankroll += int(dirty.launder("marina", dirty.dirty_balance())["clean"])  # 1650

	# Heist.
	var heist := HeistJob.new()
	heist.plan().set_approach("smart")
	for i in 3:
		heist.plan().add_prep("p%d" % i)
		heist.plan().complete_prep("p%d" % i)
	heist.crew().add_member("driver", 0.8, 0.2)
	heist.crew().add_member("hacker", 0.6, 0.2)
	bankroll += int(heist.resolve(true, 100000, 0)["take"])  # 86250

	# Stash the lot, insure a ride, build a following.
	var house := Safehouse.new()
	house.acquire("condo", "south_beach")
	house.stash(bankroll)
	var ins := VehicleInsurance.new()
	ins.insure("infernus", 40000)
	ins.destroy("infernus")
	var claim := ins.claim("infernus")
	var career := ContentCareer.new()
	career.post({"rarity": 1.0, "framing": 1.0, "lighting": 1.0, "action": 1.0, "landmark": true})

	return (
		bankroll == 89340  # 1440 + 1650 + 86250
		and house.stash_balance("condo") == 89340
		and claim["deductible"] == 4000
		and career.followers() == 500
	)
