extends Node
## Upgrades a district's greybox surfaces to physically-based materials once it
## has built: reflective glass-grey facades and wet, near-specular asphalt that
## reads as real under SSR + SDFGI + golden-hour light. Runs deferred so the
## DistrictLoader's meshes exist; assigns override materials (shared mesh
## untouched). This is the per-surface half of the "hero block" look; the scene
## supplies the environment, sun, and post.

@export var district_path: NodePath = ^"../District"


func _ready() -> void:
	call_deferred("_tune")


func _tune() -> void:
	var district := get_node_or_null(district_path)
	if district == null:
		return
	# owned=false: the district's meshes are built at runtime (no scene owner).
	for mi in district.find_children("*", "MeshInstance3D", true, false):
		var node := mi as MeshInstance3D
		if node.name.begins_with("Buildings"):
			node.set_surface_override_material(0, _facade_material())
		elif node.name.begins_with("Roads"):
			node.set_surface_override_material(0, _asphalt_material())


func _facade_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.52, 0.55, 0.6)
	m.metallic = 0.45
	m.metallic_specular = 0.6
	m.roughness = 0.32  # smooth enough for SSR window-like reflections
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.4
	# Faint warm bounce on edges sells the golden-hour grade.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _asphalt_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.06, 0.06, 0.07)
	m.metallic = 0.1
	m.metallic_specular = 0.8
	m.roughness = 0.18  # wet, reflective sheen
	return m
