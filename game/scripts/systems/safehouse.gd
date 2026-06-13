class_name Safehouse
extends RefCounted
## The player's safehouses — the sanctuary you retreat to. Each is a save/respawn
## anchor, a place to REST (skip time to cool wanted heat and heal up), and a
## STASH for cash kept safe off your person — safe even from a `MoneyLaundering`
## audit, so a smart launderer parks the clean money at home before pushing the
## dirty pile.
##
## Distinct from `PropertyOwnership` (passive INCOME), `GarageStorage` (VEHICLES),
## and `WantedEvasion` (going cold on foot by line-of-sight): this is the
## lay-low-and-bank sanctuary. Pure — a controller owns one, charges the wallet on
## acquire, and applies the rest() heat/heal amounts to `WantedSystem`/`PlayerHealth`
## itself. Deterministic; unit-tested headless (tests/unit/test_safehouse.gd).
## Persisted via to_dict/from_dict.

## Wanted heat (in WantedSystem severity units) shed per hour of rest.
const HEAT_COOL_PER_HOUR: float = 1.5
## Health points restored per hour of rest.
const HEAL_PER_HOUR: float = 20.0

var _houses: Dictionary = {}  # id -> {district, stash}
var _active: String = ""

# --- Ownership ---------------------------------------------------------------


func acquire(id: String, district: String) -> bool:
	var clean := id.strip_edges()
	if clean.is_empty() or _houses.has(clean):
		return false
	_houses[clean] = {"district": district, "stash": 0}
	if _active.is_empty():
		_active = clean  # first one bought becomes home
	return true


func has_safehouse(id: String) -> bool:
	return _houses.has(id)


func count() -> int:
	return _houses.size()


func set_active(id: String) -> bool:
	if not _houses.has(id):
		return false
	_active = id
	return true


func active() -> String:
	return _active


func district_of(id: String) -> String:
	if not _houses.has(id):
		return ""
	return _houses[id]["district"]


# --- Rest --------------------------------------------------------------------


## Skip [param hours] resting at a safehouse: returns {heat_cooled, health_restored}
## for the caller to apply. A no-op (zeros) with no safehouse owned.
func rest(hours: float) -> Dictionary:
	if _active.is_empty() or hours <= 0.0:
		return {"heat_cooled": 0.0, "health_restored": 0.0}
	return {"heat_cooled": hours * HEAT_COOL_PER_HOUR, "health_restored": hours * HEAL_PER_HOUR}


# --- Stash -------------------------------------------------------------------


## Bank cash in the active safehouse's stash (safe off your person). Returns the
## new stash balance, or -1 with no active safehouse.
func stash(amount: int) -> int:
	if _active.is_empty() or amount <= 0:
		return stash_balance(_active)
	_houses[_active]["stash"] = int(_houses[_active]["stash"]) + amount
	return _houses[_active]["stash"]


## Withdraw from the active safehouse's stash, bounded by the balance. Returns the
## amount actually taken.
func withdraw(amount: int) -> int:
	if _active.is_empty() or amount <= 0:
		return 0
	var have: int = _houses[_active]["stash"]
	var taken: int = mini(amount, have)
	_houses[_active]["stash"] = have - taken
	return taken


func stash_balance(id: String) -> int:
	if not _houses.has(id):
		return 0
	return _houses[id]["stash"]


func total_stashed() -> int:
	var total := 0
	for id in _houses:
		total += int(_houses[id]["stash"])
	return total


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"houses": _houses.duplicate(true), "active": _active}


func from_dict(data: Dictionary) -> void:
	_houses.clear()
	var saved: Dictionary = data.get("houses", {})
	for id in saved:
		var h: Dictionary = saved[id]
		_houses[str(id)] = {
			"district": str(h.get("district", "")), "stash": maxi(int(h.get("stash", 0)), 0)
		}
	var act: String = str(data.get("active", ""))
	_active = act if _houses.has(act) else ""
