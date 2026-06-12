class_name ImportedMaraProxyBinder
extends RefCounted
## Binds the Three.js-authored Mara proxy pieces to the animated Godot rig.
##
## The exported proxy is segmented and named by body part. Reparenting those
## pieces to the existing procedural rig nodes lets the imported visual inherit
## shoulder, elbow, hip, knee, ankle, torso, and head animation without requiring
## a full skinned armature yet.

const BODY_BINDINGS: Dictionary = {
	"torso_jacket": "Hips/MaraTorsoMount",
	"shirt_panel": "Hips/MaraTorsoMount",
	"jacket_lapel_l": "Hips/MaraTorsoMount",
	"jacket_lapel_r": "Hips/MaraTorsoMount",
	"cross_body_strap": "Hips/MaraTorsoMount",
	"pendant_cord": "Hips/MaraTorsoMount",
	"pendant": "Hips/MaraTorsoMount",
	"pelvis_trousers": "Hips/MaraPelvisMount",
	"belt": "Hips/MaraPelvisMount",
	"head": "Hips/MaraHeadMount",
	"hair_mass": "Hips/MaraHeadMount",
	"cap": "Hips/MaraHeadMount",
	"eye_l": "Hips/MaraHeadMount",
	"eye_r": "Hips/MaraHeadMount",
	"nose": "Hips/MaraHeadMount",
	"mouth": "Hips/MaraHeadMount",
	"earring_l": "Hips/MaraHeadMount",
	"upper_arm_l": "Hips/ShoulderL",
	"upper_arm_r": "Hips/ShoulderR",
	"forearm_l": "Hips/ShoulderL/Elbow",
	"forearm_r": "Hips/ShoulderR/Elbow",
	"hand_l": "Hips/ShoulderL/Elbow",
	"hand_r": "Hips/ShoulderR/Elbow",
	"thigh_l": "Hips/HipL",
	"thigh_r": "Hips/HipR",
	"shin_l": "Hips/HipL/Knee",
	"shin_r": "Hips/HipR/Knee",
	"boot_l": "Hips/HipL/Knee/Ankle",
	"boot_r": "Hips/HipR/Knee/Ankle",
	"thigh_band_l": "Hips/HipL",
	"thigh_band_r": "Hips/HipR",
}
const RIGGED_BONE_BINDINGS: Dictionary = {
	"MaraHips": "Hips",
	"MaraSpine": "Hips/Torso",
	"MaraChest": "Hips/Torso",
	"MaraNeck": "Hips/Neck",
	"MaraHead": "Hips/Head",
	"MaraShoulderL": "Hips/ShoulderL",
	"MaraElbowL": "Hips/ShoulderL/Elbow",
	"MaraHandL": "Hips/ShoulderL/Elbow",
	"MaraShoulderR": "Hips/ShoulderR",
	"MaraElbowR": "Hips/ShoulderR/Elbow",
	"MaraHandR": "Hips/ShoulderR/Elbow",
	"MaraHipL": "Hips/HipL",
	"MaraKneeL": "Hips/HipL/Knee",
	"MaraAnkleL": "Hips/HipL/Knee/Ankle",
	"MaraHipR": "Hips/HipR",
	"MaraKneeR": "Hips/HipR/Knee",
	"MaraAnkleR": "Hips/HipR/Knee/Ankle",
}
const TEXTURES := preload("res://scripts/player/humanoid_textures.gd")


static func finish_material(mesh: MeshInstance3D) -> void:
	var key := mesh.name.to_lower()
	var src := mesh.get_active_material(0)
	if src != null:
		key += " " + src.resource_name.to_lower()
	if key.contains("eye"):
		mesh.material_override = _eye_material()
	elif key.contains("mouth"):
		mesh.material_override = _mouth_material()
	elif (
		key.contains("skin") or key.contains("head") or key.contains("hand") or key.contains("nose")
	):
		mesh.material_override = _skin_material()
	elif key.contains("hair"):
		mesh.material_override = _hair_material()
	elif key.contains("brass") or key.contains("pendant") or key.contains("earring"):
		mesh.material_override = _metal_material()
	elif (
		key.contains("leather")
		or key.contains("black")
		or key.contains("strap")
		or key.contains("belt")
	):
		mesh.material_override = _leather_material()
	elif key.contains("shirt"):
		mesh.material_override = _fabric_material(Color(0.72, 0.72, 0.68), "shirt")
	elif (
		key.contains("fabric")
		or key.contains("trousers")
		or key.contains("thigh")
		or key.contains("shin")
	):
		mesh.material_override = _fabric_material(Color(0.42, 0.50, 0.46), "fabric")
	elif key.contains("jacket") or key.contains("lapel") or key.contains("torso"):
		mesh.material_override = _fabric_material(Color(0.02, 0.024, 0.026), "jacket")


static func bind(visual: Node3D, rig: Node) -> void:
	var proxy := visual.get_node_or_null("MaraThreeProxy") as Node3D
	if proxy != null:
		_bind_segmented_proxy(proxy, rig)
	if visual.get_node_or_null("MaraRiggedProxy") != null:
		_bind_rigged_replacement_arms(visual, rig)


static func drive_rigged(visual: Node3D, rig: Node) -> void:
	if visual == null or rig == null:
		return
	var skeleton := _find_skeleton(visual)
	if skeleton == null:
		return
	for bone_name in RIGGED_BONE_BINDINGS.keys():
		var bone_index := skeleton.find_bone(String(bone_name))
		var source := rig.get_node_or_null(String(RIGGED_BONE_BINDINGS[bone_name])) as Node3D
		if bone_index < 0 or source == null:
			continue
		skeleton.set_bone_pose_rotation(
			bone_index, source.transform.basis.get_rotation_quaternion()
		)


static func set_bound_parts_active(root: Node, active: bool) -> void:
	if root.get_meta("mara_imported_proxy_bound", false):
		root.visible = active
		if root is MeshInstance3D:
			(root as MeshInstance3D).cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if active
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
	for child in root.get_children():
		set_bound_parts_active(child, active)


static func _bind_segmented_proxy(proxy: Node3D, rig: Node) -> void:
	for part_name in BODY_BINDINGS.keys():
		var part := _find_descendant(proxy, String(part_name)) as Node3D
		var target := rig.get_node_or_null(String(BODY_BINDINGS[part_name])) as Node3D
		if part == null or target == null:
			continue
		_reparent_keep_global(part, target)
		part.set_meta("mara_three_bound_to", target.get_path())
		part.set_meta("mara_imported_proxy_bound", true)


static func _bind_rigged_replacement_arms(visual: Node3D, rig: Node) -> void:
	_hide_descendant_meshes(
		visual,
		[
			"mara_rigged_upper_arm_l",
			"mara_rigged_upper_arm_r",
			"mara_rigged_forearm_l",
			"mara_rigged_forearm_r",
			"mara_rigged_hand_l",
			"mara_rigged_hand_r",
		]
	)
	_bind_rigged_replacement_arm(visual, rig, "l", "L")
	_bind_rigged_replacement_arm(visual, rig, "r", "R")


static func _hide_descendant_meshes(root: Node, names: Array[String]) -> void:
	if root is MeshInstance3D and names.has(root.name):
		var mi := root as MeshInstance3D
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("mara_rigged_arm_skin_hidden", true)
	for child in root.get_children():
		_hide_descendant_meshes(child, names)


static func _bind_rigged_replacement_arm(
	visual: Node3D, rig: Node, mesh_suffix: String, rig_suffix: String
) -> void:
	var shoulder := rig.get_node_or_null("Hips/Shoulder%s" % rig_suffix) as Node3D
	var elbow := rig.get_node_or_null("Hips/Shoulder%s/Elbow" % rig_suffix) as Node3D
	if shoulder == null or elbow == null:
		return
	_bind_replacement_part(visual, "mara_three_replacement_shoulder_cap_%s" % mesh_suffix, shoulder)
	_bind_replacement_part(visual, "mara_three_replacement_upper_arm_%s" % mesh_suffix, shoulder)
	_bind_replacement_part(visual, "mara_three_replacement_forearm_%s" % mesh_suffix, elbow)
	_bind_replacement_part(visual, "mara_three_replacement_hand_%s" % mesh_suffix, elbow)


static func _bind_replacement_part(visual: Node3D, part_name: String, target: Node3D) -> void:
	if target.get_node_or_null(part_name) != null:
		return
	var part := _find_descendant(visual, part_name) as Node3D
	if part == null:
		return
	_reparent_keep_global(part, target)
	part.set_meta("mara_imported_proxy_bound", true)
	part.set_meta("mara_rigged_replacement_arm", true)
	if part is MeshInstance3D:
		var mesh := part as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		finish_material(mesh)


static func _find_descendant(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_descendant(child, node_name)
		if found != null:
			return found
	return null


static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


static func _reparent_keep_global(node: Node3D, target: Node3D) -> void:
	var global := node.global_transform
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	target.add_child(node)
	node.global_transform = global


static func _skin_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.55, 0.43)
	mat.roughness = 0.5
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_skin_mode = true
	mat.subsurf_scatter_strength = 0.45
	mat.rim_enabled = true
	mat.rim = 0.24
	mat.rim_tint = 0.28
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.1
	mat.clearcoat_roughness = 0.42
	_detail(mat, TEXTURES.skin_normal(), 0.42, 9.0)
	mat.set_meta("mara_imported_surface_profile", "skin")
	return mat


static func _fabric_material(color: Color, profile: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	mat.rim_enabled = true
	mat.rim = 0.08
	mat.rim_tint = 0.18
	_detail(mat, TEXTURES.fabric_normal(), 0.48, 14.0)
	mat.set_meta("mara_imported_surface_profile", profile)
	return mat


static func _leather_material() -> StandardMaterial3D:
	var mat := _fabric_material(Color(0.005, 0.005, 0.006), "leather")
	mat.roughness = 0.38
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.45
	mat.clearcoat_roughness = 0.22
	return mat


static func _eye_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.025, 0.018, 0.012)
	mat.roughness = 0.18
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.65
	mat.clearcoat_roughness = 0.08
	mat.set_meta("mara_imported_surface_profile", "eye")
	return mat


static func _mouth_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.012, 0.012)
	mat.roughness = 0.42
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.16
	mat.clearcoat_roughness = 0.3
	mat.set_meta("mara_imported_surface_profile", "mouth")
	return mat


static func _hair_material() -> StandardMaterial3D:
	var mat := _leather_material()
	mat.albedo_color = Color(0.015, 0.012, 0.01)
	mat.rim_enabled = true
	mat.rim = 0.18
	mat.set_meta("mara_imported_surface_profile", "hair")
	return mat


static func _metal_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.62, 0.24)
	mat.metallic = 0.8
	mat.roughness = 0.3
	mat.set_meta("mara_imported_surface_profile", "metal")
	return mat


static func _detail(mat: StandardMaterial3D, tex: Texture2D, strength: float, scale: float) -> void:
	mat.normal_enabled = true
	mat.normal_texture = tex
	mat.normal_scale = strength
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(scale, scale, scale)
