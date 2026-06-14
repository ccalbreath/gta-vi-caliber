class_name SideJobBoard
extends Node3D
## A playable side job: step into the JobGiver zone to accept a delivery, then
## reach the Dropoff zone to get paid a distance-scaled fare. Consumes the tested
## SideJob model and self-wires by group (player / player_stats / stats), so it's
## a self-contained activity dropped into the world — the GTA "side hustle".
##
## Expects two Area3D children named "JobGiver" and "Dropoff", each with a
## CollisionShape3D. Both watch the player's collision layer (2).

signal job_started
signal job_paid(amount: int)

## Reward = base_reward + per_meter * pickup->dropoff distance (SideJob.fare).
@export var base_reward: int = 150
@export var per_meter: float = 1.5

var _job: SideJob
var _giver: Area3D
var _dropoff: Area3D


func _ready() -> void:
	_job = SideJob.new()
	add_to_group("side_job_board")
	_giver = get_node_or_null("JobGiver") as Area3D
	_dropoff = get_node_or_null("Dropoff") as Area3D
	if _giver != null:
		_giver.collision_mask |= 2
		_giver.body_entered.connect(_on_giver_entered)
	if _dropoff != null:
		_dropoff.collision_mask |= 2
		_dropoff.body_entered.connect(_on_dropoff_entered)


func _on_giver_entered(body: Node) -> void:
	if not body.is_in_group("player") or _job.has_active():
		return
	var pickup := _giver.global_position
	var drop := _dropoff.global_position if _dropoff != null else pickup
	_job.start(SideJob.make_job(SideJob.Kind.DELIVERY, pickup, drop, base_reward))
	_job.advance_stage()  # picked up — head for the dropoff
	job_started.emit()


func _on_dropoff_entered(body: Node) -> void:
	if not body.is_in_group("player") or not _job.has_active():
		return
	var distance := _giver.global_position.distance_to(_dropoff.global_position)
	var fare := SideJob.fare(distance, base_reward, per_meter)
	_job.complete()
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats != null and stats.has_method("add_money"):
		stats.add_money(fare)
	var tracker := get_tree().get_first_node_in_group("stats")
	if tracker != null and tracker.has_method("add"):
		tracker.add("side_jobs_done", 1)
	job_paid.emit(fare)


## Completed side jobs so far, for a HUD readout.
func jobs_done() -> int:
	return _job.completed_count() if _job != null else 0
