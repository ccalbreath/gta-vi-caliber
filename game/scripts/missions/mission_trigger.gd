class_name MissionTrigger
extends Area3D
## Declarative mission trigger: when the player enters this area, mark a mission
## objective complete. Drop it into a mission scene, give it a CollisionShape3D,
## set objective_id, and either point controller_path at the MissionController or
## let it find the one in group "mission".
##
## One-shot by default (disarms after firing so re-entry doesn't double-complete).
## Thin glue over MissionController.complete(); the area is widened to also watch
## the player's collision layer so it works without per-scene mask tuning.

## Collision layer the player body lives on (player.gd sets collision_layer = 2),
## OR-ed into this area's mask so body_entered fires for the player out of the box.
const PLAYER_LAYER_BIT := 2

## The MissionObjectives id this area completes.
@export var objective_id: String = ""
## Optional explicit controller; otherwise the first node in group "mission" that
## exposes complete().
@export var controller_path: NodePath
## Re-arm after firing instead of one-shot.
@export var repeatable: bool = false

var _fired: bool = false


func _ready() -> void:
	collision_mask |= PLAYER_LAYER_BIT
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _fired and not repeatable:
		return
	if not body.is_in_group("player"):
		return
	var controller := _controller()
	if controller == null or not controller.has_method("complete"):
		return
	_fired = true
	controller.complete(objective_id)


func _controller() -> Node:
	if controller_path != NodePath() and has_node(controller_path):
		return get_node(controller_path)
	for node in get_tree().get_nodes_in_group("mission"):
		if node.has_method("complete"):
			return node
	return null
