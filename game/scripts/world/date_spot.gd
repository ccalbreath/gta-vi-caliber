class_name DateSpot
extends Area3D
## A date VENUE (a restaurant, a club, a scenic drive) of a certain date TYPE. Step in with your
## date to spend an evening here — the shared RomanceController (group "romance") charges the tab
## and builds the partner's affection, a LOT if this is their favourite kind of date and only a
## little if not, so you learn their taste and court them to commitment for a one-time milestone.
## Re-visitable (dating is ongoing). Finds the controller by group; many venues share one love
## life. Needs a CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/romance_probe.gd.

signal dated(partner_id: String, affection: float)

## Who you're taking out and what kind of evening this venue is (their favourite type builds the
## most affection). The tab must be positive — a free date can't court your way to the reward.
@export var partner_id: String = "alex"
@export var date_type: String = "dinner"
@export_range(1, 1000000) var cost: int = 1500

## True while the player is inside, so one physical visit is one date even when a compound collider
## emits body_entered several times. Cleared on exit (the beat is re-walkable).
var _player_inside: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var controller := get_tree().get_first_node_in_group("romance")
	if controller == null or not controller.has_method("go_on_date"):
		push_warning("DateSpot: no RomanceController in group 'romance' — %s inert" % partner_id)
		return
	var affection := float(controller.go_on_date(partner_id, date_type, cost))
	dated.emit(partner_id, affection)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
