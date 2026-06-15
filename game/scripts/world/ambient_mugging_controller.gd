class_name AmbientMuggingController
extends Node3D
## Spawns a victim + mugger for an ambient mugging roll and resolves when the
## mugger is killed or scared away. Consumes the tested AmbientMugging model and
## self-wires by group (ambient_mugging). Exercised by tests/ambient_mugging_probe.gd.

signal mugging_resolved(outcome: String, reward: int)

const MuggingModel: Script = preload("res://scripts/systems/ambient_mugging.gd")
const ACTOR_SCRIPT: Script = preload("res://scripts/npc/ambient_mugging_actor.gd")
const PEDESTRIAN_SCENE: PackedScene = preload("res://scenes/npc/pedestrian.tscn")
const ROLE_VICTIM: int = 0
const ROLE_MUGGER: int = 1

## How close (m) the armed player must be to intimidate the mugger.
@export var intervene_radius: float = 8.0
@export var spawn_min_radius: float = 15.0
@export var spawn_max_radius: float = 22.0
@export var mugger_offset: float = 3.0
@export var ground_probe_up: float = 8.0
@export var ground_probe_down: float = 40.0
@export_flags_3d_physics var ground_mask: int = 1

var _mugging: RefCounted = null
var _victim: Node3D = null
var _mugger: Node3D = null
var _site: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _scare_attempted: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_mugging = MuggingModel.new()
	_rng.randomize()
	add_to_group("ambient_mugging")


func _process(delta: float) -> void:
	if _mugging == null or not _mugging.is_active():
		return
	_elapsed += delta
	var mugger_dead: bool = _mugger != null and is_instance_valid(_mugger) and _mugger.is_dead()
	var mugger_fled := _mugger_fled()
	_try_scare_mugger()
	_mugging.tick(_elapsed, mugger_dead, mugger_fled, _player_near())
	var outcome: String = _mugging.outcome()
	if outcome.is_empty():
		return
	_finish(outcome)


func is_active() -> bool:
	return _mugging != null and _mugging.is_active()


func site_position() -> Vector3:
	return _site


## Begin a mugging near `origin` (typically the player's feet).
func start_encounter(origin: Vector3) -> void:
	end_encounter()
	var spawn := _pick_spawn(origin)
	if spawn == Vector3.INF:
		return
	_site = spawn
	_spawn_pair(spawn, origin)
	_elapsed = 0.0
	_scare_attempted = false
	_mugging.start(0.0)


func end_encounter() -> void:
	if _victim != null and is_instance_valid(_victim):
		_victim.queue_free()
	if _mugger != null and is_instance_valid(_mugger):
		_mugger.queue_free()
	_victim = null
	_mugger = null
	_site = Vector3.ZERO
	_mugging = MuggingModel.new()


func _finish(outcome: String) -> void:
	var reward: int = MuggingModel.reward_for(outcome)
	mugging_resolved.emit(outcome, reward)
	end_encounter()


func _spawn_pair(victim_pos: Vector3, player_pos: Vector3) -> void:
	var away := NpcBrain.planar_dir(player_pos, victim_pos)
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	var mugger_pos := victim_pos + away * mugger_offset
	mugger_pos.y = _ground_probe(mugger_pos, victim_pos.y)

	_victim = _spawn_actor(ROLE_VICTIM, victim_pos)
	_mugger = _spawn_actor(ROLE_MUGGER, mugger_pos)
	if _victim == null or _mugger == null:
		end_encounter()
		return
	_victim.set("partner", _mugger)
	_mugger.set("partner", _victim)


func _spawn_actor(role: int, pos: Vector3) -> Node3D:
	var ped := PEDESTRIAN_SCENE.instantiate() as CharacterBody3D
	if ped == null:
		return null
	ped.set_script(ACTOR_SCRIPT)
	ped.set("role", role)
	add_child(ped)
	ped.global_position = pos
	return ped


func _pick_spawn(origin: Vector3) -> Vector3:
	for _attempt in 8:
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(spawn_min_radius, spawn_max_radius)
		var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var pos := origin + offset
		var gy := _ground_probe(pos, origin.y)
		if is_nan(gy):
			continue
		pos.y = gy
		return pos
	return Vector3.INF


func _ground_probe(at: Vector3, base_y: float) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return base_y
	var from := Vector3(at.x, base_y + ground_probe_up, at.z)
	var to := Vector3(at.x, base_y - ground_probe_down, at.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	var hit := space.intersect_ray(query)
	return hit.position.y if hit.has("position") else NAN


func _mugger_fled() -> bool:
	if _mugger == null or not is_instance_valid(_mugger) or _mugger.is_dead():
		return false
	return _mugger.fear() > 0.0


func _player_near() -> bool:
	var player := _player()
	if player == null or _site == Vector3.ZERO:
		return false
	return NpcBrain.planar_distance(player.global_position, _site) <= intervene_radius


func _try_scare_mugger() -> void:
	if _scare_attempted or _mugger == null or not is_instance_valid(_mugger):
		return
	if _mugger.is_dead():
		return
	var player := _player()
	if player == null:
		return
	if NpcBrain.planar_distance(player.global_position, _mugger.global_position) > intervene_radius:
		return
	var weapon := get_tree().get_first_node_in_group("weapon_controller")
	if weapon == null or not weapon.has_method("is_armed") or not weapon.is_armed():
		return
	_scare_attempted = true
	_mugger.scare(player.global_position, 8.0)


func _player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node3D
