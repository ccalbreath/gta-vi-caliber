class_name PoliceEscalation
extends RefCounted
## Pure response-composition model for the wanted heat ramp: which KINDS of units
## a star level summons (beat cops → cruisers → SWAT → helicopter → military), how
## hard they press, how often waves reinforce, and what they shoot with.
##
## This is the unit-TYPE layer, distinct from its neighbours: PoliceResponse maps
## stars→head-count + spawn radius, and PoliceDispatch maps that count→ring spawn
## positions/recalls. PoliceEscalation answers "what responds" — the iconic GTA
## heat profile — and never how many or where.
##
## Static functions only, no scene/RNG/node state, so the curve is deterministic
## and unit-tested (tests/unit/test_police_escalation.gd). Stars are clamped to
## [0, MAX_STARS] and every curve is monotonic in stars (higher heat is never a
## weaker response). A spawner/AI layer reads response_units() to pick which
## prefabs to instance and the predicates/curves to tune their behaviour.

## Highest heat tier: 6 stars summons the military, the top of the ramp.
const MAX_STARS: int = 6

## Unit-type identifiers, ordered weakest → heaviest. Returned by response_units()
## as the composition of an active response; a spawner maps each to a prefab.
const BEAT_COP: int = 0
const CRUISER: int = 1
const SWAT: int = 2
const HELICOPTER: int = 3
const MILITARY: int = 4

## Star at which each heavy asset first joins the response (and stays, monotonic).
const SWAT_STARS: int = 3
const HELICOPTER_STARS: int = 4
const MILITARY_STARS: int = 6

## Response composition per star (index = clamped stars, 0..MAX_STARS). Each entry
## is the multiset of active unit types — the iconic ramp. Element counts only set
## the *mix*; absolute head-count lives in PoliceResponse, not here.
const RESPONSE_BY_STAR: Array = [
	[],  # 0★ — clean, no response.
	[BEAT_COP],  # 1★ — a lone beat cop on foot.
	[BEAT_COP, CRUISER, CRUISER],  # 2★ — cruisers roll in.
	[CRUISER, CRUISER, CRUISER, SWAT],  # 3★ — more cruisers + first SWAT.
	[CRUISER, CRUISER, SWAT, SWAT, HELICOPTER],  # 4★ — SWAT + chopper overhead.
	[CRUISER, SWAT, SWAT, SWAT, HELICOPTER],  # 5★ — heavier SWAT saturation.
	[SWAT, SWAT, HELICOPTER, HELICOPTER, MILITARY, MILITARY],  # 6★ — the army.
]


## Stars snapped into the valid [0, MAX_STARS] band.
static func clamp_stars(stars: int) -> int:
	return clampi(stars, 0, MAX_STARS)


## The mix of unit types active at this heat (a fresh copy, safe to mutate).
## Empty at 0★; monotonic — a higher star is never a weaker response.
static func response_units(stars: int) -> Array:
	return (RESPONSE_BY_STAR[clamp_stars(stars)] as Array).duplicate()


## Whether a SWAT unit is part of the response at this heat.
static func has_swat(stars: int) -> bool:
	return clamp_stars(stars) >= SWAT_STARS


## Whether a pursuit helicopter is part of the response at this heat.
static func has_helicopter(stars: int) -> bool:
	return clamp_stars(stars) >= HELICOPTER_STARS


## Whether the military is part of the response at this heat (6★ only).
static func has_military(stars: int) -> bool:
	return clamp_stars(stars) >= MILITARY_STARS


## 0.0 (arrest / shoot only if shot at) … 1.0 (shoot-to-kill). Rises with stars.
static func aggression(stars: int) -> float:
	return clampf(float(clamp_stars(stars)) / float(MAX_STARS), 0.0, 1.0)


## Seconds between reinforcement waves — SHORTER at higher heat (more relentless).
## 0★ returns the slow baseline (nothing actually spawns at 0★ anyway).
static func reinforcement_interval(stars: int) -> float:
	return lerpf(12.0, 3.0, aggression(stars))


## 0.0 … 1.0 chance a roadblock is set up — rises with stars, none at 0★.
static func roadblock_chance(stars: int) -> float:
	return lerpf(0.0, 0.9, aggression(stars))


## Weapon tier the response carries: 0 none/melee, 1 pistols, 2 SMGs, 3 rifles,
## 4 military-grade. Non-decreasing with stars.
static func weapon_tier(stars: int) -> int:
	var s := clamp_stars(stars)
	if s <= 0:
		return 0
	if s <= 2:
		return 1
	if s <= 3:
		return 2
	if s <= 5:
		return 3
	return 4
