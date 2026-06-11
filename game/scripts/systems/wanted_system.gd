class_name WantedSystem
extends RefCounted
## Pure heat/stars model for the wanted/police-response system.
##
## No scene access — a WantedTracker node owns one and feeds it crimes and time,
## so the escalation/decay curve is unit-tested (tests/unit/test_wanted_system.gd).
## "Heat" is an internal accumulator; players see it quantised into 0-5 stars.

const MAX_STARS: int = 5
## Heat needed for each of the 1..5 stars.
const STAR_THRESHOLDS: Array[float] = [1.0, 3.0, 6.0, 10.0, 16.0]

var heat: float = 0.0
var decay_rate: float
var heat_cap: float


func _init(decay: float = 0.4, cap: float = 20.0) -> void:
	decay_rate = decay
	heat_cap = cap


## Register a crime of the given severity (negative ignored), clamped to the cap.
func add_crime(severity: float) -> void:
	heat = minf(heat + maxf(severity, 0.0), heat_cap)


## Advance one frame. Heat only cools while no crime is in progress, so a
## sustained rampage holds the level up.
func tick(delta: float, committing: bool) -> void:
	if not committing:
		heat = maxf(heat - decay_rate * delta, 0.0)


func stars() -> int:
	return WantedSystem.stars_for(heat)


func is_wanted() -> bool:
	return heat > 0.0


## Stars for a given heat level (pure, so the HUD and tests agree).
static func stars_for(heat_value: float) -> int:
	var count := 0
	for threshold in STAR_THRESHOLDS:
		if heat_value >= threshold:
			count += 1
	return count


## How many police should be actively responding at a star level.
static func response_units(stars: int) -> int:
	return clampi(stars, 0, MAX_STARS)
