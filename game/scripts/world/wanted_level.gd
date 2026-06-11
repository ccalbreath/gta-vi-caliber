class_name WantedLevel
extends RefCounted
## Wanted/heat model: crimes raise "heat", which maps to a 0–5 star rating and
## decays over time when the player lies low. Pure and scene-free so the rules
## unit-test headless (tests/unit/test_wanted_level.gd); a HUD/AI layer reads
## stars() and reacts.

const MAX_STARS := 5
## Heat required to reach each star count (index = stars).
const STAR_THRESHOLDS := [0.0, 1.0, 3.0, 6.0, 10.0, 15.0]
## Heat added per crime kind.
const CRIME_HEAT := {
	"trespass": 0.5,
	"theft": 1.5,
	"reckless_driving": 1.0,
	"assault": 3.0,
	"shooting": 5.0,
}

var heat: float = 0.0
var cool_rate: float = 0.5  # heat lost per second while lying low


func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, STAR_THRESHOLDS[MAX_STARS])


func add_crime(kind: String) -> void:
	add_heat(CRIME_HEAT.get(kind, 1.0))


## Cool down over `delta` seconds.
func decay(delta: float) -> void:
	heat = maxf(0.0, heat - cool_rate * delta)


func stars() -> int:
	var s := 0
	for i in range(1, STAR_THRESHOLDS.size()):
		if heat >= STAR_THRESHOLDS[i]:
			s = i
	return s


func is_wanted() -> bool:
	return stars() > 0


func clear() -> void:
	heat = 0.0
