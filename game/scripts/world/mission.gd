class_name MissionObjectives
extends RefCounted
## A single mission: an ordered set of objectives and a state machine
## (inactive → active → complete/failed). Pure and scene-free so the gameplay
## rules unit-test headless (tests/unit/test_mission.gd); MissionManager and
## triggers drive it from the live world.

enum State { INACTIVE, ACTIVE, COMPLETE, FAILED }

var title: String
var state: State = State.INACTIVE
var objectives: Array = []


## objective_defs: Array of {id:String, text:String}.
func _init(mission_title: String = "", objective_defs: Array = []) -> void:
	title = mission_title
	for o in objective_defs:
		objectives.append({"id": o["id"], "text": o.get("text", ""), "done": false})


func start() -> void:
	if state == State.INACTIVE:
		state = State.ACTIVE


## Mark an objective done. Returns true if this call changed it. Completing the
## last open objective completes the mission.
func complete_objective(id: String) -> bool:
	if state != State.ACTIVE:
		return false
	for o in objectives:
		if o["id"] == id and not o["done"]:
			o["done"] = true
			if _all_done():
				state = State.COMPLETE
			return true
	return false


func fail() -> void:
	if state == State.ACTIVE:
		state = State.FAILED


func is_active() -> bool:
	return state == State.ACTIVE


func is_complete() -> bool:
	return state == State.COMPLETE


## Returns (done_count, total_count).
func progress() -> Vector2i:
	var done := 0
	for o in objectives:
		if o["done"]:
			done += 1
	return Vector2i(done, objectives.size())


func _all_done() -> bool:
	for o in objectives:
		if not o["done"]:
			return false
	return not objectives.is_empty()
