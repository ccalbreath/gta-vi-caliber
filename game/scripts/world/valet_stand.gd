class_name ValetStand
extends Area3D
## A curbside valet / garage call point for ONE personal vehicle. Step up to CALL the car:
## the shared VehicleSupplierController (group "vehicle_supplier") charges the fee and drives
## it to you, arriving after the delivery countdown. If it's already on its way or respawning
## from a wreck, the stand just flags that it's busy (no double-charge). Many stands can share
## one controller (one per vehicle). Needs a CollisionShape3D child; watches the player's
## collision layer (2). Verified in tests/vehicle_supplier_probe.gd.

signal called(id: String, eta_seconds: float)
signal busy(id: String)

## Which roster vehicle this stand summons (e.g. daily_sedan / sports_coupe / off_roader).
@export var vehicle_id: String = "daily_sedan"

## True while the player is inside, so one physical visit fires ONE call even when a compound
## collider emits body_entered several times. Cleared on exit (the stand is re-visitable).
var _player_inside: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var supplier := get_tree().get_first_node_in_group("vehicle_supplier")
	if supplier == null:
		return
	if not supplier.is_available(vehicle_id):
		busy.emit(vehicle_id)
		return
	var eta := float(supplier.request(vehicle_id))
	if eta >= 0.0:
		called.emit(vehicle_id, eta)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
