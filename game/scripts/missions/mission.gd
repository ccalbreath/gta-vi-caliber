class_name Mission
extends RefCounted
## Pure mission state: one objective with a progress count and an optional timer.
##
## No scene access — a MissionDirector owns one and feeds it kills and time, so
## the objective/fail logic is unit-tested (tests/unit/test_mission.gd). Kept
## deliberately small (single counted objective) so the framework is obvious;
## multi-step missions chain several of these.

enum Status { ACTIVE, COMPLETE, FAILED }

var title: String
var objective: String
var required: int
var progress: int = 0
var status: Status = Status.ACTIVE
## 0 = untimed; otherwise the mission fails when the clock runs out.
var time_limit: float
var time_left: float


func _init(mission_title: String, objective_text: String, target: int, limit: float = 0.0) -> void:
	title = mission_title
	objective = objective_text
	required = maxi(target, 1)
	time_limit = maxf(limit, 0.0)
	time_left = time_limit


func is_active() -> bool:
	return status == Status.ACTIVE


## Count progress toward the objective; completes (and locks) at `required`.
func record(amount: int = 1) -> void:
	if status != Status.ACTIVE:
		return
	progress = mini(progress + maxi(amount, 0), required)
	if progress >= required:
		status = Status.COMPLETE


## Advance the timer; a timed mission fails when it hits zero.
func tick(delta: float) -> void:
	if status != Status.ACTIVE or time_limit <= 0.0:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		status = Status.FAILED


func fraction() -> float:
	return float(progress) / float(required)


func reset() -> void:
	progress = 0
	status = Status.ACTIVE
	time_left = time_limit
