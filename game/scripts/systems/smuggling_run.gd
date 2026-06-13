class_name SmugglingRun
extends RefCounted
## A bulk smuggling run — the Florida sea/air gauntlet. A cargo of product runs a
## ROUTE of legs (open water, a coast-guard patrol box, the port approach), and at
## each leg an interdiction can seize a slice of what's left. Your evasion (a fast
## boat, a quiet route, a greased official) shrinks the loss at every leg, so a
## clean runner brings the whole load home while a sloppy one watches it get
## chipped away checkpoint by checkpoint.
##
## Distinct from `ContrabandMarket` (district price arbitrage on a carried parcel)
## and `DealerNetwork` (the street-corner network): this is the run-the-gauntlet
## TRIP. Pure + deterministic (interdiction is a designed fraction of the remaining
## cargo, not an RNG roll), so it unit-tests headless
## (tests/unit/test_smuggling_run.gd). A smuggling mission builds the route, runs it
## with the player's evasion, then banks `value_delivered` and applies `heat`.
## Persisted via to_dict/from_dict.

## WantedSystem heat severity per leg where something gets seized.
const HEAT_PER_INTERDICTION: int = 1

var _cargo: int = 0
var _unit_value: int = 0
var _legs: Array[float] = []  # per-leg interdiction risk, 0..1


func _init(cargo_units: int = 0, unit_value: int = 0) -> void:
	_cargo = maxi(cargo_units, 0)
	_unit_value = maxi(unit_value, 0)


# --- Route -------------------------------------------------------------------


func add_leg(risk01: float) -> void:
	_legs.append(clampf(risk01, 0.0, 1.0))


func leg_count() -> int:
	return _legs.size()


func cargo_units() -> int:
	return _cargo


func cargo_value() -> int:
	return _cargo * _unit_value


# --- Run ---------------------------------------------------------------------


## Run the route with the given evasion (0..1). At each leg the interdiction seizes
## floor(remaining * leg_risk * (1 - evasion)). Returns {delivered, seized,
## value_delivered, value_seized, interdictions, heat, busted}.
func run(evasion01: float) -> Dictionary:
	var evade := clampf(evasion01, 0.0, 1.0)
	var remaining := _cargo
	var interdictions := 0
	for risk in _legs:
		var seized := int(floor(float(remaining) * risk * (1.0 - evade)))
		if seized > 0:
			interdictions += 1
			remaining -= seized
	var seized_total := _cargo - remaining
	return {
		"delivered": remaining,
		"seized": seized_total,
		"value_delivered": remaining * _unit_value,
		"value_seized": seized_total * _unit_value,
		"interdictions": interdictions,
		"heat": interdictions * HEAT_PER_INTERDICTION,
		"busted": remaining == 0 and _cargo > 0,
	}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"cargo": _cargo, "unit_value": _unit_value, "legs": Array(_legs)}


func from_dict(data: Dictionary) -> void:
	_cargo = maxi(int(data.get("cargo", 0)), 0)
	_unit_value = maxi(int(data.get("unit_value", 0)), 0)
	_legs.clear()
	for risk in data.get("legs", []):
		_legs.append(clampf(float(risk), 0.0, 1.0))
