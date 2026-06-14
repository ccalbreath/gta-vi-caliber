class_name ScoreTarget
extends Area3D
## A robbable SCORE you case before you crack. Step in the FIRST time to MARK it — your crew
## starts casing it (recon builds on the StakeoutController's day clock). Come back once it's ripe
## and step in to MOVE IN: the take scales with how well it's cased, and a rushed (low-recon) hit
## trips the alarm. Finds the shared StakeoutController by group ("stakeout"); one mark + one hit.
## Needs a CollisionShape3D child; watches the player's collision layer (2). Verified in
## tests/stakeout_probe.gd.

signal marked
signal hit(take: int)

## True while the player is inside, so one physical visit fires ONE action even when a compound
## collider emits body_entered several times. Cleared on exit (you come back to move in).
var _player_inside: bool = false


func _ready() -> void:
	collision_mask |= 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if _player_inside or not body.is_in_group("player"):
		return
	_player_inside = true
	var controller := get_tree().get_first_node_in_group("stakeout")
	if (
		controller == null
		or not controller.has_method("move_in")
		or not controller.has_method("mark")
		or not controller.has_method("is_marked")
		or not controller.has_method("is_done")
	):
		return
	if not controller.is_marked():
		controller.mark()  # first visit: start casing it
		marked.emit()
	elif not controller.is_done():
		var take := int(controller.move_in())  # later visit: rob the cased score
		if take > 0:
			hit.emit(take)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
