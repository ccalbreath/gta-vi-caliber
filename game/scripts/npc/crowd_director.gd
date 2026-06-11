class_name CrowdDirector
extends Node3D
## Keeps a living pedestrian crowd around the player: spawns varied peds at the
## edge of view, culls them once they fall far behind, and respawns to maintain
## a target headcount — so a district feels inhabited without ever paying for
## people the player can't see (roadmap M4: "spawn/despawn invisible to player").
##
## All placement uses CrowdDistribution (pure, tested); the peds themselves are
## the premium HumanoidBody pedestrians (randomize_palette), so the crowd reads
## as distinct people. Ground height is taken from the player's Y — flat-world
## assumption for now; a navmesh/raycast sample is a later refinement.

## Pedestrian scene to populate the crowd with. Defaults to the standard one so
## the director works the moment it is dropped into a scene.
@export var pedestrian_scene: PackedScene = preload("res://scenes/npc/pedestrian.tscn")
## How many peds to keep alive around the player.
@export var target_count: int = 12
## Peds spawn in this annulus (m) around the player — far enough to fade in at
## the edge of view, never on top of them.
@export var spawn_min_radius: float = 18.0
@export var spawn_max_radius: float = 32.0
## Past this distance (m) a ped is recycled. Must exceed spawn_max_radius so a
## fresh spawn isn't instantly culled.
@export var cull_radius: float = 44.0
## Seconds between maintenance ticks — cheap, so the crowd doesn't churn the
## physics frame.
@export var tick_interval: float = 0.5
## Max peds instantiated per tick, so populating a scene is spread over a few
## ticks instead of one hitching frame.
@export var spawn_budget: int = 3
## Per-person stature: each ped is uniformly scaled within this range so the
## crowd has a believable spread of heights instead of identical clones.
@export var stature_min: float = 0.92
@export var stature_max: float = 1.08
## Per-person gait: walk/run speeds are scaled within this range (independent of
## stature) so some people stride and others amble.
@export var gait_min: float = 0.85
@export var gait_max: float = 1.15

var _peds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _accum: float = 0.0


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < tick_interval:
		return
	_accum = 0.0
	var player := _player()
	if player == null:
		return
	_cull(player.global_position)
	_spawn(player.global_position)


## Recycle peds that have drifted past the cull radius (or were freed elsewhere,
## e.g. by another system) so the active list stays tight.
func _cull(center: Vector3) -> void:
	var survivors: Array[Node3D] = []
	for ped in _peds:
		if not is_instance_valid(ped):
			continue
		var d := NpcBrain.planar_distance(ped.global_position, center)
		if CrowdDistribution.should_despawn(d, cull_radius):
			ped.queue_free()
		else:
			survivors.append(ped)
	_peds = survivors


## Top the crowd back up to target_count, a few at a time, at the spawn annulus.
func _spawn(center: Vector3) -> void:
	if pedestrian_scene == null:
		return
	var n := CrowdDistribution.spawn_count(_peds.size(), target_count, spawn_budget)
	for _i in n:
		var offset := CrowdDistribution.spawn_offset(
			spawn_min_radius, spawn_max_radius, _rng.randf(), _rng.randf()
		)
		var ped := pedestrian_scene.instantiate() as Node3D
		if ped == null:
			return
		_apply_variety(ped)
		add_child(ped)
		ped.global_position = center + offset
		_peds.append(ped)


## Give a fresh ped its own stature and gait before it enters the tree, so two
## pedestrians from the same scene never look or move identically. Uniform scale
## keeps the capsule collider valid; gait is set on the exported speeds the
## pedestrian reads each frame, so it takes effect immediately.
func _apply_variety(ped: Node3D) -> void:
	var stature := _rng.randf_range(stature_min, stature_max)
	ped.scale = Vector3(stature, stature, stature)
	var gait := _rng.randf_range(gait_min, gait_max)
	if "walk_speed" in ped:
		ped.walk_speed = ped.walk_speed * gait
	if "run_speed" in ped:
		ped.run_speed = ped.run_speed * gait


## Current live crowd size — handy for a streaming-debug HUD and for tests that
## drive the director with a stub player.
func population() -> int:
	var live := 0
	for ped in _peds:
		if is_instance_valid(ped):
			live += 1
	return live


func _player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node3D
