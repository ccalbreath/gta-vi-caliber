class_name PoliceResponse
extends RefCounted
## Maps a wanted-star count to a police response profile: how many units pursue,
## how aggressive they are, how far out they spawn, and whether a helicopter
## joins. Pure and scene-free so escalation rules unit-test headless
## (tests/unit/test_police_response.gd); a spawner/AI layer consumes the profile.

## Pursuing units per star count (index = stars, 0–5).
const UNITS_PER_STAR := [0, 1, 2, 4, 6, 8]
const HELICOPTER_STARS := 3


static func units_for(stars: int) -> int:
	return UNITS_PER_STAR[clampi(stars, 0, 5)]


static func uses_helicopter(stars: int) -> bool:
	return stars >= HELICOPTER_STARS


## 0.0 (calm) … 1.0 (lethal) — drives chase speed, fire rate, ram willingness.
static func aggression(stars: int) -> float:
	return clampf(float(stars) / 5.0, 0.0, 1.0)


## Metres from the player that new units spawn — wider nets at higher heat.
static func spawn_radius(stars: int) -> float:
	return lerpf(40.0, 140.0, aggression(stars))


## Convenience: the whole profile as a dictionary.
static func profile(stars: int) -> Dictionary:
	return {
		"units": units_for(stars),
		"helicopter": uses_helicopter(stars),
		"aggression": aggression(stars),
		"spawn_radius": spawn_radius(stars),
	}
