class_name ProtectionRacketController
extends Node
## Brings the ProtectionRacket model to life: owns the player's ONE racket, runs the daily
## tribute accrual + intimidation decay on an in-game-day clock, banks collected tribute into
## PlayerStats, and draws police HEAT each time you lean on a front (a shakedown is a violent
## crime). Self-wires by group ("protection_racket"); ShakedownFront zones lean on a front and
## collect against this one shared racket. Owns ONE ProtectionRacket
## (tests/unit/test_protection_racket.gd); verified protection_racket_probe.gd.

signal collected(amount: int)
signal front_shaken(id: String, intimidation: float)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day or a
## lag-spike delta can't run thousands of decay/accrual ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0
## Crime reports a single shakedown draws (leaning on a business is a violent crime).
const SHAKEDOWN_HEAT_REPORTS: int = 1

## How hard a single shakedown leans (the intimidation it applies). A scene could drive this
## from the player's weapon / menace.
@export_range(0.0, 1.0) var shake_force: float = 0.9
## Real seconds per in-game day for the tribute / intimidation-decay clock (<=0 pauses it).
@export var seconds_per_day: float = 90.0

var _racket: ProtectionRacket
var _day_accum: float = 0.0


func _ready() -> void:
	_racket = ProtectionRacket.new()
	add_to_group("protection_racket")


func _process(delta: float) -> void:
	if seconds_per_day <= 0.0 or _racket == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_racket.accrue(1.0)


## Lean on a front: (re)intimidates it so it pays tribute, and draws police heat — a shakedown
## is a violent crime. Returns the new intimidation, or -1.0 for an unknown front.
func shake_down(id: String) -> float:
	if _racket == null:
		return -1.0
	var level := _racket.shake_down(id, shake_force)
	if level < 0.0:
		return -1.0
	_report_heat()
	front_shaken.emit(id, level)
	return level


## Bank the accrued tribute into PlayerStats. Guards the wallet BEFORE collecting so a missing
## wallet can't drop the pot. Returns the amount collected (0 if none / no wallet).
func collect() -> int:
	if _racket == null or _racket.pending_tribute() <= 0:
		return 0
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return 0
	var amount := _racket.collect()
	stats.add_money(amount)
	collected.emit(amount)
	return amount


# --- Queries (passthroughs for the fronts / HUD) -----------------------------


func is_protected(id: String) -> bool:
	return _racket != null and _racket.is_protected(id)


func is_compliant(id: String) -> bool:
	return _racket != null and _racket.is_compliant(id)


func is_defiant(id: String) -> bool:
	return _racket != null and _racket.is_defiant(id)


func intimidation_of(id: String) -> float:
	return _racket.intimidation_of(id) if _racket != null else 0.0


func pending_tribute() -> int:
	return _racket.pending_tribute() if _racket != null else 0


func daily_income() -> int:
	return _racket.daily_income() if _racket != null else 0


func protected_count() -> int:
	return _racket.protected_count() if _racket != null else 0


# --- Internal ----------------------------------------------------------------


func _report_heat() -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted == null or not wanted.has_method("report_crime"):
		return
	for _i in SHAKEDOWN_HEAT_REPORTS:
		wanted.report_crime(false)
