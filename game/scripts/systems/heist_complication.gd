class_name HeistComplication
extends RefCounted
## The "things go wrong" layer that resolves a heist's mess — the third leg of the
## heist trio (`HeistPlan` picks the approach + prep, `HeistCrew` rolls go/no-go,
## this applies the COMPLICATIONS). The riskier the plan, the more of the
## complication table fires, mild ones first (a nosy guard) escalating to the
## job-wreckers (a blocked getaway). Each one shaves the take and piles on heat;
## a couple cost you a crew member.
##
## Stateless + deterministic (the number that fire is a function of the plan's
## risk, worst-last — no RNG), so the same risk always yields the same outcome and
## it unit-tests headless (tests/unit/test_heist_complication.gd). A mission
## resolver calls apply(base_take, base_heat, HeistPlan.risk(crew_skill)) at the
## finale and applies the returned take/heat/casualties.

## Complication table, ordered mild → job-wrecking (the order they kick in as risk
## climbs). take_mult cuts the score; heat adds WantedSystem severity.
const COMPLICATIONS := [
	{"id": "nosy_guard", "take_mult": 0.95, "heat": 1, "casualties": 0},
	{"id": "silent_alarm", "take_mult": 0.90, "heat": 2, "casualties": 0},
	{"id": "hostage_panic", "take_mult": 0.85, "heat": 1, "casualties": 0},
	{"id": "crew_member_hit", "take_mult": 0.80, "heat": 1, "casualties": 1},
	{"id": "blocked_getaway", "take_mult": 0.70, "heat": 3, "casualties": 0},
]


func count() -> int:
	return COMPLICATIONS.size()


## How many complications fire at a given plan risk (0 at risk 0, all at risk 1).
func count_for(risk01: float) -> int:
	return clampi(int(floor(clampf(risk01, 0.0, 1.0) * float(COMPLICATIONS.size()))), 0, count())


## The ids that fire at this risk (mild first).
func complications_for(risk01: float) -> PackedStringArray:
	var out := PackedStringArray()
	for i in count_for(risk01):
		out.append(COMPLICATIONS[i]["id"])
	return out


## Resolve the heist's mess: shave the take and pile on heat/casualties for every
## complication that fires at [param risk01]. Returns {take, heat, casualties, fired}.
func apply(base_take: int, base_heat: int, risk01: float) -> Dictionary:
	var take := base_take
	var heat := base_heat
	var casualties := 0
	var fired := PackedStringArray()
	for i in count_for(risk01):
		var c: Dictionary = COMPLICATIONS[i]
		take = int(floor(float(take) * float(c["take_mult"])))
		heat += int(c["heat"])
		casualties += int(c["casualties"])
		fired.append(c["id"])
	return {"take": take, "heat": heat, "casualties": casualties, "fired": fired}
