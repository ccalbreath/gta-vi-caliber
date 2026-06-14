class_name BusinessFront
extends Area3D
## A playable storefront for ONE operated business. Step in to TAKE IT OVER (first visit:
## acquire + stock + staff so it starts producing) or to CASH OUT (later visits: sell the
## accrued product at the live heat-discounted price, then restock for the next cycle so it
## keeps running while you're away). Finds the shared BusinessVentureController by group
## ("business_venture"), which owns the model + the production day clock. Many fronts can
## share one controller (one per racket). Needs a CollisionShape3D child; watches the
## player's collision layer (2). Verified in tests/business_venture_probe.gd.

signal taken_over(id: String)
signal collected(id: String, proceeds: int)

## Which catalogue venture this storefront runs (e.g. coke_lab / nightclub / weed_farm).
@export var venture_id: String = "coke_lab"
## Cost to take the racket over.
@export var acquire_cost: int = 50000
## Supply batch bought on takeover and re-bought on each cash-out (over-order is free —
## the model clamps to the supply ceiling).
@export var restock_units: int = 50
@export var supply_unit_cost: int = 200

## True while the player is inside, so one physical visit fires ONE action even when a
## compound collider emits body_entered several times. Cleared on exit (the zone is
## re-visitable — you come back to cash out).
var _player_inside: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var controller := get_tree().get_first_node_in_group("business_venture")
	if controller == null:
		return
	if controller.owns(venture_id):
		_collect(controller)
	else:
		_take_over(controller)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false


## First visit: take it over, lay in a starter supply batch, and hire a worker so the line
## actually runs. If the takeover fails (can't afford it), stock/staff are left untouched.
func _take_over(controller: Node) -> void:
	if not controller.try_acquire(venture_id, acquire_cost):
		return
	controller.try_buy_supplies(venture_id, restock_units, supply_unit_cost)
	controller.hire(venture_id)
	taken_over.emit(venture_id)


## Later visits: cash out the accrued stockpile, then restock so production continues.
func _collect(controller: Node) -> void:
	var proceeds := int(controller.cash_out(venture_id))
	controller.try_buy_supplies(venture_id, restock_units, supply_unit_cost)
	collected.emit(venture_id, proceeds)
