class_name Collectible
extends Area3D
## A hidden package on the map. Walk into it to grab it — the find is reported to the shared
## CollectiblesController (group "collection"), which banks the bounty (and the big SET-COMPLETE
## bonus when it's the last one), then it goes dormant (each is found once). Finds the controller
## by group; many collectibles share one set. Needs a CollisionShape3D child; watches the
## player's collision layer (2). Verified in tests/collectibles_probe.gd.

signal grabbed(id: String, reward: int)

## Which set item this is (must exist in the CollectiblesController's roster).
@export var collectible_id: String = "package_0"

var _taken: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	var controller := get_tree().get_first_node_in_group("collection")
	if controller == null or not controller.has_method("collect"):
		return
	var paid := int(controller.collect(collectible_id))
	if paid > 0:
		_go_dormant()
		grabbed.emit(collectible_id, paid)
	elif controller.has_method("is_found") and controller.is_found(collectible_id):
		# Already collected (e.g. restored from a save) — just go quiet, no payout.
		_go_dormant()


## The package has been grabbed: stop responding and hide it.
func _go_dormant() -> void:
	_taken = true
	visible = false
	set_deferred("monitoring", false)
