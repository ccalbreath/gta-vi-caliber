class_name BountyBoard
extends Area3D
## A most-wanted poster you take a contract off. Step up to go after this board's fugitive — the
## shared BountyBoardController (group "bounty_board") resolves the hunt at your live combat
## rating (a base competence lifted by your shooting skill). Land the catch and the bounty banks
## to PlayerStats and the poster comes down; come up OUTGUNNED and they get away — train your
## shooting and come back for the bigger names. Many boards share one roster. Needs a
## CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/bounty_hunt_probe.gd.

signal claimed(id: String, bounty: int)
signal escaped(id: String)

## Which fugitive this poster is for (must exist in the BountyHunt roster).
@export var fugitive_id: String = "petty_thief"

var _player_inside: bool = false
var _done: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or _done or not body.is_in_group("player"):
		return
	_player_inside = true
	var controller := get_tree().get_first_node_in_group("bounty_board")
	if (
		controller == null
		or not controller.has_method("attempt")
		or not controller.has_method("is_caught")
	):
		push_warning("BountyBoard: no controller in group 'bounty_board' — %s inert" % fugitive_id)
		return
	if controller.is_caught(fugitive_id):
		_done = true  # already brought in (e.g. from a save) — take the poster down
		return
	# >0 caught; 0 outgunned (genuine escape); <0 couldn't resolve (no wallet) -> stay silent.
	var outcome := int(controller.attempt(fugitive_id))
	if outcome > 0:
		_done = true
		claimed.emit(fugitive_id, outcome)
	elif outcome == 0:
		escaped.emit(fugitive_id)  # outgunned — the poster stays up, try again when sharper


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
