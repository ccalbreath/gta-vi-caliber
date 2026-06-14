class_name ShakedownFront
extends Area3D
## A business on your protection beat. Step in to make your ROUNDS: you lean on this front
## (re-intimidating it so it keeps paying — and drawing heat) AND pocket the tribute that's
## piled up across the whole racket. Neglect a front and its fear fades until it turns defiant
## and stops paying, so you have to keep walking the beat. Finds the shared
## ProtectionRacketController by group ("protection_racket"); many fronts share one racket.
## Needs a CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/protection_racket_probe.gd.

signal rounds_made(id: String, collected: int)

## Which roster front this storefront is (must exist in ProtectionRacket's catalogue).
@export var front_id: String = "liquor_store"

## True while the player is inside, so one physical visit fires ONE round even when a compound
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
	var racket := get_tree().get_first_node_in_group("protection_racket")
	if racket == null:
		return
	racket.shake_down(front_id)  # lean on them (draws heat)
	var took := int(racket.collect())  # pocket the accrued tribute across the racket
	rounds_made.emit(front_id, took)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
