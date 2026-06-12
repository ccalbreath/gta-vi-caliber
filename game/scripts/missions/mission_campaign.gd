class_name MissionCampaign
extends Node
## Turns the lone opening objective into a CAMPAIGN: drives a sequence of missions
## through the scene's single MissionController, advancing to the next when one is
## passed. Each mission re-themes the same fixed MissionTrigger zones (it reuses
## the objective ids reach_car / drive_strip / return_home with new titles+text),
## so no extra trigger geometry is needed — set those triggers `repeatable` and
## the controller `auto_start = false` so this coordinator owns sequencing.
##
## Joins group "campaign"; exposes is_campaign_complete() + mission progress for
## the HUD. All sequencing rides on the pure, tested MissionChain.

var _chain: MissionChain
var _controller: Node = null
var _started: bool = false


func _process(_delta: float) -> void:
	# Resolve + kick off on the first tick (not _ready) so the MissionController
	# has registered with group "mission" regardless of node ready order.
	if _started:
		return
	_controller = get_tree().get_first_node_in_group("mission")
	if _controller == null:
		return
	_started = true
	add_to_group("campaign")
	_chain = MissionChain.new(_missions())
	if _controller.has_signal("mission_completed"):
		_controller.connect("mission_completed", _on_mission_passed)
	_load_current()


func _missions() -> Array:
	# Same three objective ids across missions (so the fixed triggers complete
	# them), retitled and re-pathed into a three-mission opening arc.
	var waypoints := {
		"reach_car": Vector3(7, 1, 5),
		"drive_strip": Vector3(72, 1, -48),
		"return_home": Vector3(0, 1, 0),
	}
	return [
		{
			"id": "intro",
			"title": "WELCOME TO VICE CITY",
			"objective_defs":
			[
				{"id": "reach_car", "text": "Get in your car"},
				{"id": "drive_strip", "text": "Drive down to the strip"},
				{"id": "return_home", "text": "Head back to the start"},
			],
			"waypoints": waypoints,
		},
		{
			"id": "pickup",
			"title": "THE PICKUP",
			"objective_defs":
			[
				{"id": "reach_car", "text": "Get to the getaway car"},
				{"id": "drive_strip", "text": "Make the pickup downtown"},
				{"id": "return_home", "text": "Lie low back at the safehouse"},
			],
			"waypoints": waypoints,
		},
		{
			"id": "heat",
			"title": "HEAT",
			"objective_defs":
			[
				{"id": "reach_car", "text": "Grab the car, they're onto us"},
				{"id": "drive_strip", "text": "Lose the tail on the strip"},
				{"id": "return_home", "text": "Reach the safehouse clean"},
			],
			"waypoints": waypoints,
		},
		{
			"id": "deal",
			"title": "THE DEAL",
			"objective_defs":
			[
				{"id": "reach_car", "text": "Take the car to the meet"},
				{"id": "drive_strip", "text": "Close the deal downtown"},
				{"id": "return_home", "text": "Bank the cut at the safehouse"},
			],
			"waypoints": waypoints,
		},
		{
			"id": "kingpin",
			"title": "KINGPIN",
			"objective_defs":
			[
				{"id": "reach_car", "text": "One last ride"},
				{"id": "drive_strip", "text": "Take the strip — it's yours now"},
				{"id": "return_home", "text": "Return home the king of Vice City"},
			],
			"waypoints": waypoints,
		},
	]


func _load_current() -> void:
	var mission := _chain.current()
	if mission.is_empty():
		return
	_controller.title = String(mission["title"])
	_controller.objective_defs = mission["objective_defs"]
	_controller.waypoints = mission["waypoints"]
	if _controller.has_method("reset"):
		_controller.reset()


func _on_mission_passed() -> void:
	_chain.complete_current()
	if _chain.is_campaign_complete():
		return
	# Defer so the controller finishes emitting before we rebuild it.
	_load_current.call_deferred()


func is_campaign_complete() -> bool:
	return _chain != null and _chain.is_campaign_complete()


## Missions passed so far / total, for a HUD "Mission 2 of 3" readout.
func missions_done() -> int:
	return _chain.completed() if _chain != null else 0


func mission_total() -> int:
	return _chain.count() if _chain != null else 0
