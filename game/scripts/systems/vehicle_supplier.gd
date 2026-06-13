class_name VehicleSupplier
extends RefCounted
## Pure on-call vehicle delivery + respawn model — the dynamic-logistics layer that
## complements GarageStorage's instant store/retrieve. Each registered personal
## vehicle is AVAILABLE, IN_TRANSIT (requested, counting down a delivery timer), or
## DESTROYED (wrecked, counting down a respawn cooldown before it returns). The player
## calls request() to have a vehicle delivered for a fee; report_destroyed() starts a
## respawn cooldown; tick() advances the timers and reports vehicles that ARRIVED this
## frame, which a controller spawns at the saved waypoint / garage.
##
## No scene access, location-free (the caller owns the delivery waypoint and passes it
## back into the spawn): the model only tracks per-vehicle state + timers, deterministic
## and headless-tested (tests/unit/test_vehicle_supplier.gd). The request fee resolves
## against a wallet balance the caller applies, like PropertyOwnership.buy.
##
## Catalogue row: {id, name, delivery_seconds, respawn_seconds, request_cost}. Rows
## with a missing/empty id, or a duplicate id, are dropped; cost clamped >= 0 and
## timers to a positive minimum.

enum State { AVAILABLE, IN_TRANSIT, DESTROYED }

const DEFAULT_DELIVERY_SECONDS: float = 60.0
const DEFAULT_RESPAWN_SECONDS: float = 300.0
const DEFAULT_REQUEST_COST: int = 200
## Timers are always a real positive countdown (no instant-arrival ambiguity).
const MIN_TIMER_SECONDS: float = 0.5

## id -> {name, delivery_seconds, respawn_seconds, request_cost, state, timer}.
var _vehicles: Dictionary = {}


func _init(vehicles: Array = []) -> void:
	var source: Array = vehicles if not vehicles.is_empty() else default_vehicles()
	for entry: Variant in source:
		_register(entry)


## Built-in personal-vehicle roster (delivery + respawn seconds, on-call fee).
static func default_vehicles() -> Array:
	return [
		{"id": "daily_sedan", "name": "Daily Sedan", "delivery_seconds": 45.0, "request_cost": 150},
		{
			"id": "sports_coupe",
			"name": "Sports Coupe",
			"delivery_seconds": 60.0,
			"request_cost": 350
		},
		{"id": "off_roader", "name": "Off-Roader", "delivery_seconds": 90.0, "request_cost": 250},
	]


# --- Roster ---------------------------------------------------------------


func vehicle_count() -> int:
	return _vehicles.size()


func has_vehicle(id: String) -> bool:
	return _vehicles.has(id)


func ids() -> Array:
	var out: Array = _vehicles.keys()
	out.sort()
	return out


# --- State queries (false / sentinels for unknown) ------------------------


func is_available(id: String) -> bool:
	return _vehicles.has(id) and int(_vehicles[id]["state"]) == State.AVAILABLE


func is_in_transit(id: String) -> bool:
	return _vehicles.has(id) and int(_vehicles[id]["state"]) == State.IN_TRANSIT


func is_destroyed(id: String) -> bool:
	return _vehicles.has(id) and int(_vehicles[id]["state"]) == State.DESTROYED


## Seconds until this vehicle becomes available again (0 if already available, -1 if
## unknown).
func eta_of(id: String) -> float:
	if not _vehicles.has(id):
		return -1.0
	return _vehicles[id]["timer"]


func available_count() -> int:
	var count: int = 0
	for id: String in _vehicles:
		if int(_vehicles[id]["state"]) == State.AVAILABLE:
			count += 1
	return count


## Vehicles currently in transit or respawning.
func pending_count() -> int:
	return _vehicles.size() - available_count()


# --- Requesting / lifecycle ------------------------------------------------


## Call for a vehicle to be delivered (starts the delivery timer) against a wallet.
## Returns {success, eta_seconds, cost, new_balance, reason}. Fails for unknown id, a
## vehicle that isn't AVAILABLE (already coming / wrecked), or insufficient funds.
func request(id: String, balance: int) -> Dictionary:
	if not _vehicles.has(id):
		return _fail(balance, "unknown vehicle: %s" % id)
	if int(_vehicles[id]["state"]) != State.AVAILABLE:
		return _fail(balance, "not available: %s" % id)
	var cost: int = _vehicles[id]["request_cost"]
	if balance < cost:
		return _fail(balance, "insufficient funds: need %d, have %d" % [cost, balance])
	_vehicles[id]["state"] = State.IN_TRANSIT
	_vehicles[id]["timer"] = float(_vehicles[id]["delivery_seconds"])
	return {
		"success": true,
		"eta_seconds": float(_vehicles[id]["delivery_seconds"]),
		"cost": cost,
		"new_balance": balance - cost,
		"reason": "",
	}


## Mark a vehicle wrecked: it goes DESTROYED and starts its respawn cooldown. Returns
## false for an unknown vehicle, or one still IN_TRANSIT (it isn't in the world yet, so
## it can't be wrecked — and destroying it must not bypass the paid delivery timer).
func report_destroyed(id: String) -> bool:
	if not _vehicles.has(id):
		return false
	if int(_vehicles[id]["state"]) == State.IN_TRANSIT:
		return false
	_vehicles[id]["state"] = State.DESTROYED
	_vehicles[id]["timer"] = float(_vehicles[id]["respawn_seconds"])
	return true


## Advance all timers by `delta_seconds`. Returns {vehicle_id, event} for each vehicle
## that became AVAILABLE this tick — event is "delivered" (was in transit) or
## "respawned" (was wrecked). Non-positive spans are ignored.
func tick(delta_seconds: float) -> Array:
	var arrivals: Array = []
	if delta_seconds <= 0.0:
		return arrivals
	for id: String in _vehicles:
		var state: int = _vehicles[id]["state"]
		if state == State.AVAILABLE:
			continue
		var remaining: float = float(_vehicles[id]["timer"]) - delta_seconds
		if remaining <= 0.0:
			_vehicles[id]["state"] = State.AVAILABLE
			_vehicles[id]["timer"] = 0.0
			var event: String = "delivered" if state == State.IN_TRANSIT else "respawned"
			arrivals.append({"vehicle_id": id, "event": event})
		else:
			_vehicles[id]["timer"] = remaining
	return arrivals


## Force a vehicle back to AVAILABLE immediately (e.g. loading a save / debug).
func make_available(id: String) -> void:
	if not _vehicles.has(id):
		return
	_vehicles[id]["state"] = State.AVAILABLE
	_vehicles[id]["timer"] = 0.0


# --- Persistence ----------------------------------------------------------


func serialize() -> Dictionary:
	var states: Dictionary = {}
	for id: String in ids():
		states[id] = {"state": _vehicles[id]["state"], "timer": _vehicles[id]["timer"]}
	return {"vehicles": states}


## Restore per-vehicle state + timer. Unknown ids dropped; an out-of-range state falls
## back to AVAILABLE; timer clamped >= 0; malformed input leaves the roster at defaults.
func restore(data: Dictionary) -> void:
	var stored: Variant = data.get("vehicles")
	if not (stored is Dictionary):
		return
	var states: Dictionary = stored
	for key: Variant in states:
		var id: String = str(key)
		if not _vehicles.has(id) or not (states[key] is Dictionary):
			continue
		var row: Dictionary = states[key]
		var state: int = int(row.get("state", State.AVAILABLE))
		if state < State.AVAILABLE or state > State.DESTROYED:
			state = State.AVAILABLE
		_vehicles[id]["state"] = state
		_vehicles[id]["timer"] = maxf(float(row.get("timer", 0.0)), 0.0)


# --- Internal -------------------------------------------------------------


func _fail(balance: int, reason: String) -> Dictionary:
	return {
		"success": false,
		"eta_seconds": 0.0,
		"cost": 0,
		"new_balance": balance,
		"reason": reason,
	}


## Validate and store one catalogue row; drops malformed (no/empty id) + duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _vehicles.has(id):
		return
	_vehicles[id] = {
		"name": str(row.get("name", id)),
		"delivery_seconds":
		maxf(float(row.get("delivery_seconds", DEFAULT_DELIVERY_SECONDS)), MIN_TIMER_SECONDS),
		"respawn_seconds":
		maxf(float(row.get("respawn_seconds", DEFAULT_RESPAWN_SECONDS)), MIN_TIMER_SECONDS),
		"request_cost": maxi(int(row.get("request_cost", DEFAULT_REQUEST_COST)), 0),
		"state": State.AVAILABLE,
		"timer": 0.0,
	}
