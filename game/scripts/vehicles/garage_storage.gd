class_name GarageStorage
extends RefCounted
## Pure garage / vehicle-storage model — the GTA "park it in your garage" system:
## owned vehicles (by id) are stored across one or more garages, retrieved when the
## player wants to drive them, and impounded by the cops when abandoned.
##
## STATEFUL instance, no nodes, no wallet coupling: recovering an impounded vehicle
## resolves against a balance the caller passes in and returns the result so the
## caller applies the spend (PlayerStats.spend_money) — same headless, unit-testable
## pattern as PropertyOwnership / VehicleModShop. Covered by
## tests/unit/test_garage_storage.gd.
##
## A vehicle is in exactly one of three states: out (the default — drivable / in the
## world), stored (parked in a specific garage), or impounded (seized by the cops).
## Each garage holds up to `_capacity` vehicles. Garages are created lazily on first
## store, so any garage_id is valid and starts empty with the default capacity.

## Per-garage storage cap (vehicles). Set once in _init.
var _capacity: int = 4
## garage_id -> Array[String] of stored vehicle ids (insertion order preserved).
var _garages: Dictionary = {}
## Set of impounded vehicle ids: vehicle_id -> true.
var _impounded: Dictionary = {}


func _init(capacity_per_garage: int = 4) -> void:
	_capacity = maxi(1, capacity_per_garage)


# --- Storage --------------------------------------------------------------


## Park a vehicle in a garage. Fails (state unchanged) when the garage is full,
## the vehicle is already stored somewhere, or the vehicle is impounded.
func store(garage_id: String, vehicle_id: String) -> bool:
	if vehicle_id.is_empty():
		return false
	if _impounded.has(vehicle_id):
		return false
	if is_stored(vehicle_id):
		return false
	if count_in(garage_id) >= _capacity:
		return false
	if not _garages.has(garage_id):
		_garages[garage_id] = []
	_garages[garage_id].append(vehicle_id)
	return true


## Pull a vehicle out of a garage (it becomes out / drivable). Fails when the
## vehicle is not stored in that specific garage.
func retrieve(garage_id: String, vehicle_id: String) -> bool:
	if not _garages.has(garage_id):
		return false
	var contents: Array = _garages[garage_id]
	var idx := contents.find(vehicle_id)
	if idx == -1:
		return false
	contents.remove_at(idx)
	return true


# --- Queries --------------------------------------------------------------


func is_stored(vehicle_id: String) -> bool:
	return garage_of(vehicle_id) != ""


## The garage a vehicle is parked in, or "" if it is out / impounded / unknown.
func garage_of(vehicle_id: String) -> String:
	for garage_id: String in _garages:
		if _garages[garage_id].has(vehicle_id):
			return garage_id
	return ""


## Stored vehicle ids in a garage (a copy, in insertion order; empty if unknown).
func contents(garage_id: String) -> Array:
	if not _garages.has(garage_id):
		return []
	return _garages[garage_id].duplicate()


func count_in(garage_id: String) -> int:
	if not _garages.has(garage_id):
		return 0
	return _garages[garage_id].size()


## Remaining slots in a garage (capacity for an unknown / empty garage).
func free_space(garage_id: String) -> int:
	return _capacity - count_in(garage_id)


func capacity() -> int:
	return _capacity


## Total vehicles parked across every garage.
func total_stored() -> int:
	var sum := 0
	for garage_id: String in _garages:
		sum += _garages[garage_id].size()
	return sum


# --- Impound --------------------------------------------------------------


## Flag a vehicle as impounded by the cops (e.g. abandoned in the street). Pulls it
## out of any garage it was parked in first, so it can't be both stored and seized.
func impound(vehicle_id: String) -> void:
	if vehicle_id.is_empty():
		return
	var garage_id := garage_of(vehicle_id)
	if garage_id != "":
		_garages[garage_id].erase(vehicle_id)
	_impounded[vehicle_id] = true


func is_impounded(vehicle_id: String) -> bool:
	return _impounded.has(vehicle_id)


## Pay the impound fee to release a vehicle against a wallet balance. On success the
## vehicle becomes out (available, not re-stored) and the caller applies the spend.
## Fails (state unchanged) when the vehicle isn't impounded or funds fall short.
## Returns {success, cost, new_balance, reason}.
func recover_from_impound(vehicle_id: String, balance: int, fee: int) -> Dictionary:
	if not _impounded.has(vehicle_id):
		return _fail(balance, "not impounded: %s" % vehicle_id)
	var cost := maxi(0, fee)
	if balance < cost:
		return _fail(balance, "insufficient funds: need %d, have %d" % [cost, balance])
	_impounded.erase(vehicle_id)
	return {
		"success": true,
		"cost": cost,
		"new_balance": balance - cost,
		"reason": "",
	}


# --- Persistence ----------------------------------------------------------


func serialize() -> Dictionary:
	var garages: Dictionary = {}
	for garage_id: String in _garages:
		garages[garage_id] = _garages[garage_id].duplicate()
	return {
		"capacity": _capacity,
		"garages": garages,
		"impounded": _impounded.keys(),
	}


## Rebuild from a serialize() snapshot. Malformed input is dropped defensively;
## over-capacity garages are truncated to the restored capacity.
func restore(data: Dictionary) -> void:
	_garages = {}
	_impounded = {}
	var cap: Variant = data.get("capacity", _capacity)
	if cap is int and cap >= 1:
		_capacity = cap
	var garages: Variant = data.get("garages")
	if garages is Dictionary:
		for garage_id: Variant in garages:
			_restore_garage(str(garage_id), garages[garage_id])
	var impounded: Variant = data.get("impounded")
	if impounded is Array:
		for entry: Variant in impounded:
			var id := str(entry)
			if not id.is_empty():
				_impounded[id] = true


## Empty every garage and clear all impounds.
func reset() -> void:
	_garages = {}
	_impounded = {}


# --- Internal -------------------------------------------------------------


func _fail(balance: int, reason: String) -> Dictionary:
	return {"success": false, "cost": 0, "new_balance": balance, "reason": reason}


## Restore one garage's contents, skipping non-string ids and honouring capacity.
func _restore_garage(garage_id: String, raw: Variant) -> void:
	if not (raw is Array) or garage_id.is_empty():
		return
	var clean: Array = []
	for entry: Variant in raw:
		if not (entry is String) or entry.is_empty():
			continue
		if clean.size() >= _capacity:
			break
		clean.append(entry)
	_garages[garage_id] = clean
