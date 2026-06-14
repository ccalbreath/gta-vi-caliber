extends Node3D
## A minimal playable mission, demonstrating the Mission framework end to end:
## spawns two checkpoint markers; walking the player into each completes an
## objective, and reaching both completes the mission. Real missions will load
## objective/trigger definitions from data, but this proves the loop works.

var _mission: MissionObjectives


func _ready() -> void:
	_mission = MissionObjectives.new(
		"Welcome to LA",
		[
			{"id": "a", "text": "Reach the first marker"},
			{"id": "b", "text": "Reach the second marker"}
		]
	)
	_mission.start()
	_spawn_checkpoint("a", Vector3(25, 1.5, 0))
	_spawn_checkpoint("b", Vector3(-25, 1.5, 0))


func _spawn_checkpoint(id: String, pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 4.0
	shape.shape = sphere
	area.add_child(shape)

	var marker := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 8.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.0)
	cyl.material = mat
	marker.mesh = cyl
	marker.position = Vector3(0, 4, 0)
	area.add_child(marker)

	add_child(area)
	area.body_entered.connect(_on_checkpoint.bind(id, area))


func _on_checkpoint(body: Node3D, id: String, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _mission.complete_objective(id):
		return
	area.queue_free()
	var p := _mission.progress()
	print("mission '%s': objective %s done (%d/%d)" % [_mission.title, id, p.x, p.y])
	if _mission.is_complete():
		print("MISSION COMPLETE: %s" % _mission.title)
