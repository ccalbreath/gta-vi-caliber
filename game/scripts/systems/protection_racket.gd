class_name ProtectionRacket
extends RefCounted
## Pure protection-racket ledger — lean on local businesses for a weekly cut. The mechanic
## that sets it apart from owning a business (BusinessVenture) or holding turf (GangTerritory):
## INTIMIDATION DECAYS. A shaken-down front pays TRIBUTE while it's still scared, but the fear
## fades a little each day — let it slip below the compliance line and the owner turns DEFIANT
## and stops paying until you lean on them again. So a racket isn't passive income; it's a
## beat you have to keep walking.
##
## No nodes, no wallet coupling: collect() reports the banked tribute for the caller to add to
## PlayerStats, and shake_down()/accrue() only move the intimidation + tribute numbers.
## Deterministic, unit-tested headless (tests/unit/test_protection_racket.gd).

const MIN_INTIMIDATION: float = 0.0
const MAX_INTIMIDATION: float = 1.0
## At/above this intimidation a protected front stays compliant and pays; below it, defiant.
const COMPLIANCE_THRESHOLD: float = 0.3
## Intimidation lost per in-game day (the beating fades from memory, they get bolder).
const DEFAULT_FEAR_DECAY: float = 0.1

## id -> {name, tribute_per_day, intimidation, protected}. The shakedown-able fronts.
var _fronts: Dictionary = {}
## Tribute collected from fronts but not yet banked.
var _pending: float = 0.0
var _fear_decay: float


func _init(fronts: Array = [], fear_decay: float = DEFAULT_FEAR_DECAY) -> void:
	_fear_decay = maxf(fear_decay, 0.0)
	var source: Array = fronts if not fronts.is_empty() else default_fronts()
	for entry: Variant in source:
		_register(entry)


## Built-in roster of local fronts (tribute is money/day).
static func default_fronts() -> Array:
	return [
		{"id": "liquor_store", "name": "Stop-N-Go Liquor", "tribute_per_day": 300},
		{"id": "pawn_shop", "name": "Gold Coast Pawn", "tribute_per_day": 450},
		{"id": "diner", "name": "Sunrise Diner", "tribute_per_day": 250},
		{"id": "nightclub", "name": "Neon Room", "tribute_per_day": 800},
	]


# --- Queries -----------------------------------------------------------------


func front_count() -> int:
	return _fronts.size()


func has_front(id: String) -> bool:
	return _fronts.has(id)


func is_protected(id: String) -> bool:
	return _fronts.has(id) and bool(_fronts[id]["protected"])


## Intimidation level of a front (0 if unknown / never shaken).
func intimidation_of(id: String) -> float:
	return float(_fronts[id]["intimidation"]) if _fronts.has(id) else 0.0


## A protected front still scared enough to pay (intimidation at/above the line).
func is_compliant(id: String) -> bool:
	return is_protected(id) and intimidation_of(id) >= COMPLIANCE_THRESHOLD


## A protected front whose fear has faded below the line — it has stopped paying.
func is_defiant(id: String) -> bool:
	return is_protected(id) and intimidation_of(id) < COMPLIANCE_THRESHOLD


func pending_tribute() -> int:
	return int(_pending)


## Tribute per day across every CURRENTLY-compliant front (what the racket nets right now).
func daily_income() -> int:
	var sum := 0
	for id: String in _fronts:
		if is_compliant(id):
			sum += int(_fronts[id]["tribute_per_day"])
	return sum


func protected_count() -> int:
	var count := 0
	for id: String in _fronts:
		if bool(_fronts[id]["protected"]):
			count += 1
	return count


# --- Mutations ---------------------------------------------------------------


## Lean on a front: marks it protected and raises its intimidation to `force` (a shakedown can
## only scare them MORE, never less). Returns the new intimidation, or -1.0 for an unknown id.
func shake_down(id: String, force: float) -> float:
	if not _fronts.has(id):
		return -1.0
	_fronts[id]["protected"] = true
	_fronts[id]["intimidation"] = maxf(
		float(_fronts[id]["intimidation"]), clampf(force, MIN_INTIMIDATION, MAX_INTIMIDATION)
	)
	return float(_fronts[id]["intimidation"])


## Advance `days`: every front that is COMPLIANT at the start of the span pays its tribute into
## the pot, then intimidation fades on all protected fronts. Non-positive spans are ignored.
func accrue(days: float) -> void:
	if days <= 0.0:
		return
	for id: String in _fronts:
		if not bool(_fronts[id]["protected"]):
			continue
		if float(_fronts[id]["intimidation"]) >= COMPLIANCE_THRESHOLD:
			_pending += float(_fronts[id]["tribute_per_day"]) * days
		_fronts[id]["intimidation"] = maxf(
			float(_fronts[id]["intimidation"]) - _fear_decay * days, MIN_INTIMIDATION
		)


## Bank the accrued whole-money tribute (the caller credits PlayerStats), carrying any
## sub-integer remainder so nothing is silently lost across collections.
func collect() -> int:
	var amount := int(_pending)
	_pending -= float(amount)
	return amount


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	var fronts: Dictionary = {}
	for id: String in _fronts:
		fronts[id] = {
			"intimidation": _fronts[id]["intimidation"],
			"protected": _fronts[id]["protected"],
		}
	return {"fronts": fronts, "pending": _pending}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	_pending = maxf(float(d.get("pending", 0.0)), 0.0)
	var stored: Variant = d.get("fronts")
	if not (stored is Dictionary):
		return
	var fronts: Dictionary = stored
	for key: Variant in fronts:
		var id: String = str(key)
		if not _fronts.has(id) or not (fronts[key] is Dictionary):
			continue
		var row: Dictionary = fronts[key]
		_fronts[id]["intimidation"] = clampf(
			float(row.get("intimidation", 0.0)), MIN_INTIMIDATION, MAX_INTIMIDATION
		)
		_fronts[id]["protected"] = bool(row.get("protected", false))


# --- Internal ----------------------------------------------------------------


func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _fronts.has(id):
		return
	var tribute: int = int(row.get("tribute_per_day", 0))
	if tribute <= 0:
		return
	_fronts[id] = {
		"name": str(row.get("name", id)),
		"tribute_per_day": tribute,
		"intimidation": 0.0,
		"protected": false,
	}
