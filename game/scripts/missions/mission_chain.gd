class_name MissionChain
extends RefCounted
## A campaign: an ordered list of missions the player works through one at a
## time, the layer above a single MissionController. Holds each mission's
## definition ({id, title, objective_defs, waypoints}), tracks which is active,
## and advances to the next when one completes — so the world can offer a real
## progression instead of a lone objective.
##
## Pure and node-free (unit-tested headless). A coordinator node feeds current()
## into a MissionController on start and calls complete_current() when that
## controller emits mission_completed, then re-arms the controller with the next
## current(). When is_campaign_complete() the coordinator stops re-arming.

var _missions: Array = []
var _index: int = 0


func _init(missions: Array = []) -> void:
	_missions = missions.duplicate()


## How many missions the campaign holds.
func count() -> int:
	return _missions.size()


## Index of the active mission (== count() once every mission is done).
func active_index() -> int:
	return _index


## The active mission definition, or {} when the campaign is finished/empty.
func current() -> Dictionary:
	if _index < 0 or _index >= _missions.size():
		return {}
	return _missions[_index] as Dictionary


## id of the active mission, or "" when none remains.
func current_id() -> String:
	var mission := current()
	return String(mission.get("id", "")) if not mission.is_empty() else ""


## Close the active mission and arm the next. No-op once the campaign is done, so
## a double-fire from the controller can't run the index off the end.
func complete_current() -> void:
	if _index < _missions.size():
		_index += 1


## Every mission finished (or an empty campaign — nothing to do).
func is_campaign_complete() -> bool:
	return _index >= _missions.size()


## Missions still to play, including the active one.
func remaining() -> int:
	return maxi(_missions.size() - _index, 0)


## Missions completed so far.
func completed() -> int:
	return mini(_index, _missions.size())


## Campaign progress 0.0 .. 1.0 (1.0 for an empty campaign — already done).
func progress() -> float:
	if _missions.is_empty():
		return 1.0
	return clampf(float(_index) / float(_missions.size()), 0.0, 1.0)


## Restart the campaign from the first mission.
func reset() -> void:
	_index = 0
