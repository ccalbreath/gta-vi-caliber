class_name PropertyListing
extends Area3D
## A property on the market — drive the flip one stage per visit. Stepping in as the player calls
## the realty desk to advance this property (buy → renovate → sell); each visit performs the next
## stage and the listing reports the resulting state. Re-visitable until it's sold (a terminal
## stage). Pair one per property; a scene sets `property_id` to a PropertyFlip listing id.

signal advanced(property_id: String, state: String)

@export var property_id: String = "harbor_loft"

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var controller := get_tree().get_first_node_in_group("realty")
	if controller == null or not controller.has_method("advance"):
		push_warning("PropertyListing '%s' found no realty controller" % property_id)
		return
	var state: String = controller.advance(property_id)
	advanced.emit(property_id, state)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
