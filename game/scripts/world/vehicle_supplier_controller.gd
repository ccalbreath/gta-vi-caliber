class_name VehicleSupplierController
extends Node
## Brings the previously-unwired VehicleSupplier model to life: the on-call personal-vehicle
## delivery service (call for your car and it's driven to you for a fee; wreck it and it
## comes back after a respawn cooldown) — the dynamic-logistics layer atop GarageStorage's
## instant retrieve. Self-wires by group ("vehicle_supplier"): ValetStand zones request
## against it, and the vehicle/damage side reports wrecks via report_destroyed(). Runs the
## delivery/respawn countdown on the REAL-TIME frame clock and emits vehicle_delivered /
## vehicle_respawned for the scene to spawn the car at its waypoint (the spawn is the scene's
## job — this owns only the timers + the fee). Owns ONE VehicleSupplier
## (tests/unit/test_vehicle_supplier.gd); verified vehicle_supplier_probe.gd.

signal vehicle_requested(id: String, eta_seconds: float)
signal vehicle_delivered(id: String)
signal vehicle_respawned(id: String)

## Optional custom vehicle roster (catalogue rows {id, name, delivery_seconds,
## respawn_seconds, request_cost}); empty uses the model's built-in personal-vehicle roster.
@export var roster: Array = []

var _supplier: VehicleSupplier


func _ready() -> void:
	_supplier = VehicleSupplier.new(roster)
	add_to_group("vehicle_supplier")


func _process(delta: float) -> void:
	if _supplier == null:
		return
	for arrival: Dictionary in _supplier.tick(delta):
		if String(arrival["event"]) == "delivered":
			vehicle_delivered.emit(String(arrival["vehicle_id"]))
		else:
			vehicle_respawned.emit(String(arrival["vehicle_id"]))


## Call for a vehicle, paying the fee from PlayerStats. The model only starts the timer when
## the wallet can cover the fee (it validates balance before mutating), so the follow-up
## spend can't half-charge. A free (cost 0) vehicle is summoned without a spend. Returns the
## ETA seconds, or -1.0 on any failure (no wallet / unknown / not available / can't afford).
func request(id: String) -> float:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("spend_money") or not _supplier.is_available(id):
		return -1.0
	var result := _supplier.request(id, int(stats.money))
	if not result["success"]:
		return -1.0
	var cost := int(result["cost"])
	if cost > 0 and not stats.spend_money(cost):
		# Impossible under the current wallet (the model already validated funds), but if a
		# future spend rule rejects after the check, roll the dispatch back so the car can't
		# arrive unpaid — the model was never really committed (make_available resets it).
		_supplier.make_available(id)
		return -1.0
	var eta := float(result["eta_seconds"])
	vehicle_requested.emit(id, eta)
	return eta


## Mark a delivered vehicle wrecked — it starts its respawn cooldown. False if unknown or
## still in transit (it isn't in the world yet). The vehicle/damage side calls this.
func report_destroyed(id: String) -> bool:
	return _supplier.report_destroyed(id) if _supplier != null else false


# --- Queries (passthroughs for stands / HUD) ---------------------------------


func is_available(id: String) -> bool:
	return _supplier != null and _supplier.is_available(id)


func is_in_transit(id: String) -> bool:
	return _supplier != null and _supplier.is_in_transit(id)


func is_destroyed(id: String) -> bool:
	return _supplier != null and _supplier.is_destroyed(id)


## Seconds until this vehicle is available again (0 if available, -1 if unknown).
func eta_of(id: String) -> float:
	return _supplier.eta_of(id) if _supplier != null else -1.0


func available_count() -> int:
	return _supplier.available_count() if _supplier != null else 0
