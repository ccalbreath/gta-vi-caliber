extends RefCounted
## Cross-system composition tests — proof that this session's new pure systems form a
## coherent, usable simulation layer (not isolated models), exercising the documented
## seams between them and with existing systems (WantedSystem, GangTerritory). See
## tests/run_tests.gd for the runner contract: test_* methods return true to pass.
##
## Each test wires two or more systems the way a live controller would, so the whole
## layer is ready to drop into the scene once that integration unblocks.


func test_notoriety_powers_witness_intimidation() -> bool:
	# CrimeNotoriety.fear_level() feeds NpcCompliance.intimidate() as the menace: a
	# notorious player leans on a witness far harder than a clean one.
	var notorious := CrimeNotoriety.new()
	notorious.record("cop_killing", 100.0)
	var nc := NpcCompliance.new()
	var feared := nc.intimidate("scared_bystander", notorious.fear_level(), 0.5)
	nc.reset_npc("scared_bystander")
	var clean := nc.intimidate("scared_bystander", CrimeNotoriety.new().fear_level(), 0.5)
	var feared_delta: float = feared["delta"]
	var clean_delta: float = clean["delta"]
	return feared_delta > clean_delta


func test_collision_drives_both_wear_and_citation() -> bool:
	# One crash damages the car (VehicleCondition) AND earns a reckless ticket
	# (TrafficCitation).
	var vc := VehicleCondition.new()
	var before := vc.engine_wear_of("sedan")
	vc.apply_crash("sedan", 0.6)
	var tc := TrafficCitation.new()
	var citation := tc.record_collision(45.0, false)
	return (
		vc.engine_wear_of("sedan") > before
		and citation["success"]
		and citation["kind"] == "reckless"
	)


func test_traffic_citation_escalates_into_wanted() -> bool:
	# A hit-and-run + cop-witnessed red-light run promote the civil debt into real
	# WantedSystem heat — the civil->criminal seam.
	var tc := TrafficCitation.new()
	tc.record_collision(40.0, true)  # hit-and-run
	tc.record_red_light(TrafficCitation.Light.RED, 0.0, 40.0, true)  # cop-witnessed
	var ws := WantedSystem.new()
	ws.add_crime(tc.consume_star_severity())
	return ws.stars() >= 1


func test_turf_takeover_provokes_rival_retaliation() -> bool:
	# Taking a gang's turf (GangTerritory owner) builds a grudge (RivalRetaliation)
	# that strikes back.
	var owner := GangTerritory.new().owner_of("downtown")
	var rr := RivalRetaliation.new()
	rr.provoke(owner, 80.0)
	var strikes := rr.tick(3.0)
	return (
		rr.is_seeking_revenge(owner) and strikes.size() == 1 and strikes[0]["faction_id"] == owner
	)


func test_economy_modifiers_scale_money() -> bool:
	# A feared player is gouged by shops (CrimeNotoriety) while challenge modifiers
	# boost a heist take (MissionModifier) — two money transforms a reward calc applies.
	var feared := CrimeNotoriety.new()
	feared.record("cop_killing", 100.0)
	var gouged := int(1000 * feared.shop_price_multiplier())
	var mm := MissionModifier.new()
	mm.activate("no_damage")
	var heist_take := mm.apply_to_payout(10000)
	return gouged > 1000 and heist_take > 10000


func test_getaway_delivery_then_hazard_on_route() -> bool:
	# Call a getaway car (VehicleSupplier) and drive a route through a hazard zone
	# (EnvironmentalHazard).
	var vs := VehicleSupplier.new()
	var req := vs.request("daily_sedan", 1000)
	vs.tick(50.0)  # delivery completes
	var eh := EnvironmentalHazard.new()
	var dmg := eh.damage_at(Vector3(100, 0, 100), 1.0, 0.0)  # the toxic dump
	return req["success"] and vs.is_available("daily_sedan") and dmg > 0.0


func test_gunshot_alerts_witness_who_can_be_silenced() -> bool:
	# SoundPropagation alarms a bystander to a gunshot; NpcCompliance can then
	# intimidate that witness into silence.
	var listeners: Array = [{"pos": Vector3(3, 0, 0), "id": "bystander"}]
	var heard := SoundPropagation.emit(
		Vector3.ZERO, SoundPropagation.Sound.GUNSHOT, listeners, 0.05
	)
	var alarmed: bool = heard[0]["reaction"] == SoundPropagation.Reaction.ALARMED
	var nc := NpcCompliance.new()
	for _i in 4:
		nc.intimidate("scared_bystander", 1.0, 1.0)
	return alarmed and nc.will_silence_witness("scared_bystander")


func test_business_income_funds_a_bribe() -> bool:
	# Run a coke lab (BusinessVenture), sell the product, and spend the proceeds
	# bribing an NPC (NpcCompliance) — the economy funds the interaction layer.
	var bv := BusinessVenture.new()
	bv.acquire("coke_lab", 0, 100000)
	bv.buy_supplies("coke_lab", 400, 1, 1000)
	bv.accrue(1.0)
	var sale := bv.sell("coke_lab", 5, 1.0, 0.0)
	var proceeds: int = sale["proceeds"]
	var nc := NpcCompliance.new()
	var bribe := nc.bribe("greedy_fixer", 500, proceeds)
	return proceeds >= 500 and bribe["success"] and bribe["new_balance"] == proceeds - 500
