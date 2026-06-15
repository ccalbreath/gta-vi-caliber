extends SceneTree
## Runtime probe for AmbientEncounterSpawner mugging wiring in miami.tscn. Boots
## the map, simulates a mugging roll, asserts the encounter activates with a HUD
## objective, then resolves when the mugger is killed.
##   godot --headless --path game --script res://tests/ambient_mugging_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90
const RESOLVE_FRAMES: int = 30
const EXPECTED_OBJECTIVE: String = "Stop the mugging"
const SAVED_REWARD: int = 250

var _scene: Node = null
var _frames: int = 0
var _phase: int = 0
var _money_before: int = 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("ambient mugging probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _phase == 0:
		if _frames < WARMUP_FRAMES:
			return false
		var err := _verify_start()
		if not err.is_empty():
			return _fail(err)
		_phase = 1
		_frames = 0
		return false
	if _frames < RESOLVE_FRAMES:
		return false
	var err2 := _verify_resolved()
	if err2.is_empty():
		print("ambient mugging probe: OK (encounter active + objective + resolved)")
		quit(0)
	else:
		return _fail(err2)
	return true


func _verify_start() -> String:
	var spawner := _scene.find_child("AmbientEncounterSpawner", true, false)
	if spawner == null:
		return "AmbientEncounterSpawner not present in miami.tscn"
	if spawner.has_method("_connect_director"):
		spawner._connect_director()
	var director := _scene.find_child("AmbientEventDirector", true, false)
	if director == null:
		return "AmbientEventDirector not present in miami.tscn"
	if not director.encounter_triggered.is_connected(Callable(spawner, "_on_encounter")):
		return "spawner not wired to AmbientEventDirector.encounter_triggered"
	var mugging := get_first_node_in_group("ambient_mugging")
	if mugging == null:
		return "AmbientMuggingController not in group ambient_mugging"
	var stats := get_first_node_in_group("player_stats")
	if stats == null:
		return "no player_stats node"
	if "money" in stats:
		_money_before = int(stats.money)
	spawner.call("_on_encounter", "mugging", "crime")
	return _post_trigger_errors(mugging, stats)


func _post_trigger_errors(mugging: Node, stats: Node) -> String:
	if not mugging.has_method("is_active") or not mugging.is_active():
		return "mugging did not activate after mugging encounter"
	if not ("objective_title" in stats) or String(stats.objective_title).is_empty():
		return "player_stats objective not set after mugging encounter"
	if String(stats.objective_title) != EXPECTED_OBJECTIVE:
		return "unexpected objective '%s'" % stats.objective_title
	var mugger := get_first_node_in_group("mugging_mugger")
	if mugger == null:
		return "no mugger spawned in group mugging_mugger"
	if mugger.has_method("take_damage"):
		mugger.take_damage(999.0, mugger.global_position, Vector3.UP)
	return ""


func _verify_resolved() -> String:
	var mugging := get_first_node_in_group("ambient_mugging")
	if mugging != null and mugging.has_method("is_active") and mugging.is_active():
		return "mugging still active after mugger killed"
	var stats := get_first_node_in_group("player_stats")
	if stats == null:
		return "no player_stats node"
	if "objective_title" in stats and String(stats.objective_title) == EXPECTED_OBJECTIVE:
		return "objective not cleared after mugging resolved"
	if "money" in stats and int(stats.money) < _money_before + SAVED_REWARD:
		return "reward not paid after mugging saved"
	return ""


func _fail(reason: String) -> bool:
	push_error("ambient mugging probe FAIL: " + reason)
	quit(1)
	return true
