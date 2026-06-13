class_name VehicleInsurance
extends RefCounted
## Vehicle DESTRUCTION insurance — the "Mors Mutual" cover. Insure a vehicle for a
## one-off premium (a fraction of its value); if it later gets blown up or written
## off, file a claim and pay a deductible to have it replaced. The deductible is
## far cheaper than re-buying, so insuring your prized ride is worth it — but each
## claim is real money, so demolition derbies still cost you.
##
## Distinct from `GarageStorage` (which handles the cops IMPOUNDING a parked car —
## a release fee): this is DESTRUCTION → replacement. Pure + deterministic, no
## wallet coupling (the caller charges the premium/deductible and respawns the
## car), unit-tested headless (tests/unit/test_vehicle_insurance.gd). Persisted via
## to_dict/from_dict.

## One-off premium to insure, as a fraction of vehicle value.
const PREMIUM_RATE: float = 0.05
## Deductible to recover a destroyed vehicle, as a fraction of its value.
const DEDUCTIBLE_RATE: float = 0.10

var _policies: Dictionary = {}  # id -> {value, destroyed}
var _claims: int = 0

# --- Coverage ----------------------------------------------------------------


## Insure a vehicle. Returns {success, premium} — the caller charges the premium.
## Fails if already insured or the value is non-positive.
func insure(id: String, value: int) -> Dictionary:
	var clean := id.strip_edges()
	if clean.is_empty() or value <= 0 or _policies.has(clean):
		return {"success": false, "premium": 0}
	_policies[clean] = {"value": value, "destroyed": false}
	return {"success": true, "premium": int(round(float(value) * PREMIUM_RATE))}


func cancel(id: String) -> bool:
	if not _policies.has(id):
		return false
	_policies.erase(id)
	return true


func is_insured(id: String) -> bool:
	return _policies.has(id)


func is_destroyed(id: String) -> bool:
	return _policies.has(id) and bool(_policies[id]["destroyed"])


func coverage_value(id: String) -> int:
	if not _policies.has(id):
		return 0
	return _policies[id]["value"]


func coverage_count() -> int:
	return _policies.size()


func claims_filed() -> int:
	return _claims


# --- Lifecycle ---------------------------------------------------------------


## Report a vehicle written off. If it was insured it becomes claimable; otherwise
## it's just gone. Returns {claimable}.
func destroy(id: String) -> Dictionary:
	if not _policies.has(id):
		return {"claimable": false}
	_policies[id]["destroyed"] = true
	return {"claimable": true}


## File a claim on a destroyed, insured vehicle: returns {success, deductible} and
## resets it to active (insured, not destroyed) so the caller can respawn it.
## Fails if the vehicle isn't insured or wasn't destroyed.
func claim(id: String) -> Dictionary:
	if not is_destroyed(id):
		return {"success": false, "deductible": 0}
	_policies[id]["destroyed"] = false
	_claims += 1
	var value: int = _policies[id]["value"]
	return {"success": true, "deductible": int(round(float(value) * DEDUCTIBLE_RATE))}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"policies": _policies.duplicate(true), "claims": _claims}


func from_dict(data: Dictionary) -> void:
	_policies.clear()
	var saved: Dictionary = data.get("policies", {})
	for id in saved:
		var p: Dictionary = saved[id]
		_policies[str(id)] = {
			"value": maxi(int(p.get("value", 0)), 0), "destroyed": bool(p.get("destroyed", false))
		}
	_claims = maxi(int(data.get("claims", 0)), 0)
