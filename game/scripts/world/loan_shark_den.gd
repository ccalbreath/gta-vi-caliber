class_name LoanSharkDen
extends Area3D
## Visit your loan shark: step in OWING and you make a PAYMENT toward the debt; step in DEBT-
## FREE and you take a fresh LOAN (quick cash now, brutal interest later). Finds the shared
## LoanSharkController by group ("loan_shark"). One action per physical visit (debounced on
## enter, re-armed on exit). Needs a CollisionShape3D child; watches the player's collision
## layer (2). Verified in tests/loan_shark_probe.gd.

signal loan_taken(amount: int)
signal payment_made(amount: int, cleared: bool)

## Cash taken when you arrive debt-free, and paid down when you arrive owing.
@export var loan_amount: int = 20000
@export var payment_amount: int = 8000

## True while the player is inside, so one physical visit fires ONE action even when a
## compound collider emits body_entered several times. Cleared on exit (re-visitable).
var _player_inside: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var shark := get_tree().get_first_node_in_group("loan_shark")
	if shark == null:
		return
	if shark.has_debt():
		var paid := int(shark.repay(payment_amount))
		if paid > 0:
			payment_made.emit(paid, not shark.has_debt())
	else:
		var took := int(shark.borrow(loan_amount))
		if took > 0:
			loan_taken.emit(took)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
