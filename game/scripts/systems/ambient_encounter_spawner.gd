class_name AmbientEncounterSpawner
extends Node
## Connects AmbientEventDirector.encounter_triggered to live encounter handlers.
## Self-wiring: finds the director sibling and gameplay nodes by group, then
## activates encounters when a freeroam roll fires. Handles street_race and
## mugging; other ids are ignored until a later pass adds spawn logic.
## Exercised by tests/ambient_street_race_probe.gd and tests/ambient_mugging_probe.gd.

signal encounter_started(id: String, kind: String)

const STREET_RACE_OBJECTIVE: String = "Street race: hit the checkpoints"
const MUGGING_OBJECTIVE: String = "Stop the mugging"

var _director: AmbientEventDirector = null
var _race: RaceController = null
var _mugging: Node = null
var _race_finished_connected: bool = false
var _mugging_connected: bool = false


func _ready() -> void:
	call_deferred("_connect_director")


func _connect_director() -> void:
	_director = _find_director()
	if _director == null:
		return
	if not _director.encounter_triggered.is_connected(_on_encounter):
		_director.encounter_triggered.connect(_on_encounter)
	_race = get_tree().get_first_node_in_group("race") as RaceController
	if _race != null and not _race_finished_connected:
		_race.race_finished.connect(_on_race_finished)
		_race_finished_connected = true
	_mugging = get_tree().get_first_node_in_group("ambient_mugging")
	if _mugging != null and not _mugging_connected and _mugging.has_signal("mugging_resolved"):
		_mugging.mugging_resolved.connect(_on_mugging_resolved)
		_mugging_connected = true


func _on_encounter(id: String, kind: String) -> void:
	if id == "street_race":
		_start_street_race()
		return
	if id == "mugging":
		_start_mugging()
		return
	encounter_started.emit(id, kind)


func _start_street_race() -> void:
	if _race == null:
		_race = get_tree().get_first_node_in_group("race") as RaceController
	if _race == null:
		return
	_race.start_challenge()
	var waypoint := _race.first_checkpoint()
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats != null and stats.has_method("set_objective"):
		stats.set_objective(STREET_RACE_OBJECTIVE, waypoint, waypoint != Vector3.ZERO)
	encounter_started.emit("street_race", "race")


func _start_mugging() -> void:
	if _mugging == null:
		_mugging = get_tree().get_first_node_in_group("ambient_mugging")
	if _mugging == null or not _mugging.has_method("start_encounter"):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_mugging.start_encounter(player.global_position)
	if not _mugging.has_method("is_active") or not _mugging.is_active():
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	var site: Vector3 = (
		_mugging.site_position() if _mugging.has_method("site_position") else Vector3.ZERO
	)
	if stats != null and stats.has_method("set_objective"):
		stats.set_objective(MUGGING_OBJECTIVE, site, site != Vector3.ZERO)
	encounter_started.emit("mugging", "crime")


func _on_race_finished(_reward: int) -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("clear_objective"):
		return
	if not ("objective_title" in stats):
		return
	if String(stats.objective_title) == STREET_RACE_OBJECTIVE:
		stats.clear_objective()


func _on_mugging_resolved(outcome: String, reward: int) -> void:
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null:
		return
	if "objective_title" in stats and String(stats.objective_title) == MUGGING_OBJECTIVE:
		if stats.has_method("clear_objective"):
			stats.clear_objective()
	if outcome == "saved" and reward > 0 and stats.has_method("add_money"):
		stats.add_money(reward)


func _find_director() -> AmbientEventDirector:
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is AmbientEventDirector:
				return child as AmbientEventDirector
			if child.name == "AmbientEventDirector" and child.has_signal("encounter_triggered"):
				return child as AmbientEventDirector
	return get_tree().get_first_node_in_group("ambient_event_director") as AmbientEventDirector
