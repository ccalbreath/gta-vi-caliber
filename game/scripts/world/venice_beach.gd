class_name VeniceBeach
extends Node3D
## Root script for the coastal district scene. The shared DistrictLoader picks
## a spawn by "road vertex nearest the world origin", which for a district
## 20 km west of downtown lands on its inland edge — so once the district is
## built, re-anchor the player and spawn markers to the shoreline where the
## coastal postcard actually is.

## Offset from the Beach node's centre to the spawn point on the sand line.
## Relative, not absolute: FloatingOrigin recentres the world when the player
## spawns 21 km from the engine origin, so any hard-coded world position
## would re-teleport the player out and trigger a second shift.
@export var spawn_offset: Vector3 = Vector3(1457.0, 3.5, 0.0)


func _ready() -> void:
	var district := find_child("District", false, false)
	if district != null and district.has_signal("district_built"):
		district.district_built.connect(_on_district_built)
	# Children _ready before the root: the district has usually already built
	# (and emitted) by the time we connect, so re-anchor once now as well.
	_on_district_built.call_deferred(0, 0)


func _on_district_built(_buildings: int, _roads: int) -> void:
	var beach := find_child("Beach", false, false) as Node3D
	if beach == null:
		return
	var spawn := beach.global_position + spawn_offset
	for marker in get_tree().get_nodes_in_group("spawn_points"):
		if marker is Node3D:
			(marker as Node3D).global_position = spawn
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node3D:
			(player as Node3D).global_position = spawn + Vector3(0, 0.5, 0)
