class_name RaceController
extends Node3D
## A playable checkpoint street race: pass through each checkpoint in order to
## finish a lap, and finishing pays a placement-scaled reward. Consumes the
## tested StreetRace model and self-wires by group (player / player_stats /
## stats). Checkpoints are this node's child Marker3D positions, in order.

signal race_finished(reward: int)

## Cash for finishing 1st (solo here, so always 1st).
@export var base_reward: int = 5000
@export var laps: int = 1
## How close (m) the player must get to a checkpoint to clear it.
@export var checkpoint_radius: float = 7.0

var _race: StreetRace
var _player: Node3D = null
var _done: bool = false


func _ready() -> void:
	add_to_group("race")
	var checkpoints: Array = []
	for child in get_children():
		var marker := child as Marker3D
		if marker != null:
			checkpoints.append(marker.global_position)
	_race = StreetRace.new(checkpoints, maxi(laps, 1))


func _process(delta: float) -> void:
	if _done or _race == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	_race.tick(delta)
	_race.reached(_player.global_position, checkpoint_radius)
	if _race.is_finished():
		_finish()


func _finish() -> void:
	_done = true
	var reward := StreetRace.reward(1, base_reward)
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats != null and stats.has_method("add_money"):
		stats.add_money(reward)
	var tracker := get_tree().get_first_node_in_group("stats")
	if tracker != null and tracker.has_method("add"):
		tracker.add("races_won", 1)
	race_finished.emit(reward)


## Whether the race has been completed, for a HUD readout.
func is_complete() -> bool:
	return _done


## Race progress 0..1, for a HUD bar.
func progress() -> float:
	return _race.progress() if _race != null else 0.0
