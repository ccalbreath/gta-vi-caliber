class_name Informant
extends Area3D
## A criminal informant you keep on the payroll. Step up to MEET them: the shared
## InformantController (group "informants") charges your retainer to build their trust, then —
## once they trust you enough — hands over a reliable cash tip (which spends down their intel, so
## you keep coming back to cultivate them). Re-visitable: cultivating an informant is an ongoing
## relationship, not a one-shot. Finds the controller by group; many informants share one network.
## Needs a CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/informant_probe.gd.

signal met(id: String, tip_cash: int)

## Which contact this is (must exist in the InformantNetwork roster).
@export var informant_id: String = "fixer"
## What you slip them each visit to build their trust (a non-positive retainer is rejected).
@export_range(1, 1000000) var retainer: int = 3000

## True while the player is inside, so one physical visit makes ONE meet even when a compound
## collider emits body_entered several times. Cleared on exit (the beat is re-walkable).
var _player_inside: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var controller := get_tree().get_first_node_in_group("informants")
	if controller == null or not controller.has_method("meet"):
		push_warning(
			"Informant: no InformantController in group 'informants' — %s inert" % informant_id
		)
		return
	var cash := int(controller.meet(informant_id, retainer))
	met.emit(informant_id, cash)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
