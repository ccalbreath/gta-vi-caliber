class_name StoreRobbery
extends RefCounted
## The stick-up — robbing a store register, the opportunistic small crime between
## the big planned heists. A store holds till cash that refills over time; how much
## you walk out with scales with how hard you lean on the clerk (a terrified clerk
## empties the drawer, a defiant one gives you the minimum). Lean too softly and
## they hit the SILENT ALARM, so the cops come faster and the heat is higher.
##
## Distinct from `HeistJob` (a planned multi-stage score) and `AmbientEvents`'
## random street mugging: this is the register-cash mechanic for a fixed store.
## Pure + deterministic (no RNG — intimidation maps straight to take + alarm), so
## it unit-tests headless (tests/unit/test_store_robbery.gd). A store trigger owns
## one; on a robbery `rob(intimidation)` returns the take (credited by the caller)
## + the heat to feed `WantedSystem` + whether the alarm tripped. Persisted via
## to_dict/from_dict.

## Base WantedSystem heat for an armed robbery, plus extra if the alarm trips.
const ROBBERY_HEAT: int = 3
const ALARM_HEAT: int = 2
## Intimidation below this trips the silent alarm.
const ALARM_THRESHOLD: float = 0.5
## Take fraction of the till at the weakest vs the strongest intimidation.
const MIN_TAKE_FRAC: float = 0.4
const MAX_TAKE_FRAC: float = 1.0

var _register: int = 0
var _max: int = 0
var _refill_per_day: int = 0


func _init(register_cash: int = 0, refill_per_day: int = 0) -> void:
	_register = maxi(register_cash, 0)
	_max = _register
	_refill_per_day = maxi(refill_per_day, 0)


# --- Queries -----------------------------------------------------------------


func register_balance() -> int:
	return _register


func till_capacity() -> int:
	return _max


# --- Robbery -----------------------------------------------------------------


## Rob the register. [param intimidation01] (0..1) drives how much of the till you
## take and whether the clerk trips the alarm. Returns {took, heat, alarm}.
func rob(intimidation01: float) -> Dictionary:
	var intim := clampf(intimidation01, 0.0, 1.0)
	var take_frac := lerpf(MIN_TAKE_FRAC, MAX_TAKE_FRAC, intim)
	var took := int(floor(float(_register) * take_frac))
	_register -= took
	var alarm := intim < ALARM_THRESHOLD
	var heat := ROBBERY_HEAT + (ALARM_HEAT if alarm else 0)
	return {"took": took, "heat": heat, "alarm": alarm}


## Refill the till over time (capped at its capacity).
func refill(days: float) -> int:
	if days > 0.0 and _refill_per_day > 0:
		_register = mini(_register + int(floor(float(_refill_per_day) * days)), _max)
	return _register


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"register": _register, "max": _max, "refill_per_day": _refill_per_day}


func from_dict(data: Dictionary) -> void:
	_max = maxi(int(data.get("max", 0)), 0)
	_register = clampi(int(data.get("register", 0)), 0, _max)
	_refill_per_day = maxi(int(data.get("refill_per_day", 0)), 0)
