extends Node3D
## Viewer for the AI-generated 3D character mesh.
##
## Loads the Hunyuan3D-derived character GLB (built from the Codex/GPT character
## reference, see docs/ASSETS.md), stands it on the ground under cinematic
## lighting, and slowly turntables it so you can inspect the geometry from every
## angle. Untextured for now (clay) — texturing + rigging are the next steps.
## Open this scene and press F5, or set it as the run scene.

const MODEL_PATH: String = "res://assets/characters/char_hunyuan.glb"

var _subject: Node3D


func _ready() -> void:
	var world_env := WorldEnvironment.new()
	world_env.environment = CinematicEnvironment.build()
	add_child(world_env)

	_add_light(Vector3(-42.0, -115.0, 0.0), 2.2, Color(1.0, 0.97, 0.92), true)
	_add_light(Vector3(-18.0, 70.0, 0.0), 0.8, Color(0.78, 0.84, 1.0), false)
	_add_light(Vector3(-72.0, 150.0, 0.0), 0.5, Color(1.0, 0.92, 0.84), false)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.21, 0.24)
	floor_mat.roughness = 0.5
	floor_mat.metallic = 0.1
	plane.material = floor_mat
	floor_mi.mesh = plane
	add_child(floor_mi)

	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("char3d_preview: could not load %s" % MODEL_PATH)
		return
	_subject = packed.instantiate() as Node3D
	add_child(_subject)

	# Neutral clay so the untextured mesh reads as form, not a black silhouette.
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.79, 0.75, 0.71)
	clay.roughness = 0.55
	for node in _subject.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = clay

	# Stand the figure on the floor (its mesh is centred on the origin).
	var box := _subject_aabb()
	_subject.position.y = -box.position.y
	var height: float = maxf(box.size.y, 0.5)

	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(
		Vector3(height * 0.4, height * 0.55, height * 1.4),
		Vector3(0.0, height * 0.5, 0.0),
		Vector3.UP
	)


func _add_light(rot: Vector3, energy: float, color: Color, shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rot
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = shadow
	add_child(light)


func _process(delta: float) -> void:
	if _subject != null:
		_subject.rotate_y(delta * 0.5)  # slow turntable


func _subject_aabb() -> AABB:
	var box := AABB()
	var first := true
	for node in _subject.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.transform * mi.mesh.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box if not first else AABB(Vector3.ZERO, Vector3.ONE)
