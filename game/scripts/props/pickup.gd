class_name Pickup
extends Area3D
## A floating, spinning collectible that grants an effect when the player walks
## into it, then goes dormant and respawns.
##
## Self-contained: detects the player by group on body entry, applies its effect
## to the player_health group (medkit), and toggles its own mesh/monitoring. Add
## a MeshInstance3D + CollisionShape3D child and set collision_mask to the
## player's layer. Today it heals; the same shell extends to armor/ammo/cash by
## switching the effect in _grant().

signal collected

## "health" heals, "armor" grants body armor.
@export var kind: String = "health"
@export var heal_amount: float = 40.0
@export var armor_amount: float = 50.0
@export var respawn_delay: float = 12.0
@export var spin_speed: float = 1.6
@export var bob_height: float = 0.14
@export var bob_speed: float = 2.2

var _available: bool = true
var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _available:
		return
	_time += delta
	rotation.y += spin_speed * delta
	position.y = _base_y + sin(_time * bob_speed) * bob_height


func _on_body_entered(body: Node) -> void:
	if not _available or not body.is_in_group("player"):
		return
	if not _grant():
		return
	collected.emit()
	_set_available(false)
	if respawn_delay > 0.0:
		get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


# Apply the pickup's effect; returns true if it actually did something (so a
# full-health player doesn't waste the medkit).
func _grant() -> bool:
	var granted := false
	for health in get_tree().get_nodes_in_group("player_health"):
		if kind == "armor":
			if (
				health.has_method("add_armor")
				and health.has_method("armor_fraction")
				and health.armor_fraction() < 1.0
			):
				health.add_armor(armor_amount)
				granted = true
		elif (
			health.has_method("heal") and health.has_method("fraction") and health.fraction() < 1.0
		):
			health.heal(heal_amount)
			granted = true
	return granted


func _set_available(value: bool) -> void:
	_available = value
	monitoring = value
	visible = value
	if value:
		position.y = _base_y


func _respawn() -> void:
	_set_available(true)
