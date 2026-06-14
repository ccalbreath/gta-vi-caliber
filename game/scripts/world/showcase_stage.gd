extends Node3D
## A cinematic "hero shot" stage: the premium player under CinematicEnvironment
## with three-point lighting on a soft reflective floor. Builds itself in _ready
## so the scene file stays a one-node stub. Used as a presentation/QA scene for
## the character at its highest fidelity; safe to boot headlessly.

@export var character_scene: PackedScene


func _ready() -> void:
	var world_env := WorldEnvironment.new()
	world_env.environment = CinematicEnvironment.build()
	add_child(world_env)

	_add_light(Vector3(-48.0, -125.0, 0.0), 1.6, Color(1.0, 0.97, 0.92), true)  # key
	_add_light(Vector3(-18.0, 60.0, 0.0), 0.5, Color(0.7, 0.8, 1.0), false)  # cool rim
	_add_light(Vector3(-70.0, 150.0, 0.0), 0.3, Color(1.0, 0.9, 0.8), false)  # back fill

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22, 0.23, 0.26)
	floor_mat.roughness = 0.4
	floor_mat.metallic = 0.1
	plane.material = floor_mat
	floor_mesh.mesh = plane
	add_child(floor_mesh)

	var scene := character_scene if character_scene != null else _load_player()
	if scene != null:
		add_child(scene.instantiate())

	var marker := Marker3D.new()
	marker.add_to_group("spawn_points")
	add_to_group("world")


func _add_light(rot: Vector3, energy: float, color: Color, shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rot
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = shadow
	add_child(light)


func _load_player() -> PackedScene:
	if ResourceLoader.exists("res://scenes/player/player.tscn"):
		return load("res://scenes/player/player.tscn") as PackedScene
	return null
