extends SceneTree
## Import guard for the Three.js-authored rigged Mara prototype.

const RIGGED_SCENE := "res://assets/characters/mara_three_rigged_proxy.glb"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const REQUIRED_BONES: PackedStringArray = [
	"MaraHips",
	"MaraSpine",
	"MaraChest",
	"MaraHead",
	"MaraShoulderL",
	"MaraElbowL",
	"MaraHandL",
	"MaraHipL",
	"MaraKneeL",
	"MaraAnkleL",
]
const REQUIRED_MESH_NAMES: PackedStringArray = [
	"mara_rigged_jacket",
	"mara_rigged_jacket_front_panel_l",
	"mara_rigged_jacket_front_panel_r",
	"mara_rigged_head",
	"mara_rigged_skin_face_mask",
	"mara_rigged_upper_arm_l",
	"mara_rigged_thigh_l",
	"mara_rigged_shirt_draped_front",
	"mara_rigged_trouser_front_panel_l",
	"mara_rigged_boot_l",
	"mara_rigged_cross_body_strap",
	"mara_rigged_mouth",
	"mara_rigged_mouth_upper_lip",
	"mara_rigged_mouth_lower_lip",
	"mara_rigged_cheek_l",
	"mara_rigged_eye_socket_shadow_l",
	"mara_rigged_eye_sclera_l",
	"mara_rigged_eye_iris_l",
	"mara_rigged_upper_eyelid_l",
	"mara_rigged_lower_eyelid_l",
	"mara_rigged_eye_highlight_l",
	"mara_rigged_cornea_glint_l",
	"mara_rigged_lid_crease_l",
	"mara_rigged_lash_l",
	"mara_rigged_skin_brow_ridge_l",
	"mara_rigged_skin_under_eye_shadow_l",
	"mara_rigged_nostril_l",
	"mara_rigged_skin_nasolabial_fold_l",
	"mara_rigged_skin_temple_l",
	"mara_rigged_mouth_corner_l",
	"mara_rigged_mouth_soft_seam",
	"mara_rigged_philtrum_l",
	"mara_rigged_skin_under_lip_plane",
	"mara_rigged_chin",
	"mara_rigged_jaw_shadow_l",
	"mara_rigged_brow_l",
	"mara_rigged_hair_crown",
	"mara_rigged_hairline",
	"mara_rigged_hair_forelock",
	"mara_rigged_hair_sideburn_l",
	"mara_rigged_hair_parting_line",
	"mara_rigged_hairline_wisps_l",
	"mara_rigged_hair_lock_l",
	"mara_rigged_hair_strand_l",
	"mara_rigged_hair_flyaway_l",
	"mara_rigged_hair_nape_layer_l",
	"mara_rigged_jacket_lapel_l",
	"mara_rigged_jacket_collar_l",
	"mara_rigged_jacket_zipper",
	"mara_rigged_jacket_zipper_pull",
	"mara_rigged_jacket_seam_l",
	"mara_rigged_jacket_topstitch_l",
	"mara_rigged_sleeve_wrinkle_l",
	"mara_rigged_shirt_fold_l",
	"mara_rigged_belt",
	"mara_rigged_belt_buckle",
	"mara_rigged_strap_buckle",
	"mara_rigged_cargo_pocket_l",
	"mara_rigged_trouser_crease_l",
	"mara_rigged_knee_fold_l",
	"mara_rigged_thigh_side_seam_l",
	"mara_rigged_boot_sole_l",
	"mara_rigged_boot_toe_l",
	"mara_rigged_boot_lace_l",
	"mara_rigged_boot_rivet_outer_l",
	"mara_rigged_thumb_l",
	"mara_rigged_palm_pad_l",
	"mara_rigged_index_knuckle_l",
	"mara_rigged_index_finger_l",
	"mara_rigged_index_nail_l",
	"mara_rigged_middle_finger_l",
	"mara_rigged_middle_nail_l",
	"mara_rigged_ring_finger_l",
	"mara_three_replacement_shoulder_cap_l",
	"mara_three_replacement_shoulder_slope_l",
	"mara_three_replacement_upper_arm_l",
	"mara_three_replacement_upper_arm_sleeve_panel_l",
	"mara_three_replacement_forearm_l",
	"mara_three_replacement_forearm_cuff_l",
	"mara_three_replacement_hand_l",
]


func _initialize() -> void:
	var scene := load(RIGGED_SCENE) as PackedScene
	if scene == null:
		_fail("could not load rigged Mara GLB")
		return
	var imported := scene.instantiate()
	if imported == null:
		_fail("could not instantiate rigged Mara GLB")
		return
	root.add_child(imported)
	var skeleton := _find_skeleton(imported)
	if skeleton == null:
		_fail("rigged Mara GLB did not import a Skeleton3D")
		return
	if not _check_rigged_asset(imported, skeleton):
		return
	print("player_mara_rigged_asset: OK")
	quit(0)


func _check_rigged_asset(imported: Node3D, skeleton: Skeleton3D) -> bool:
	return (
		_has_required_bones(skeleton)
		and _has_required_meshes(imported)
		and _check_face_mask_density(imported)
		and _check_player_rig_can_drive(imported, skeleton)
	)


func _has_required_bones(skeleton: Skeleton3D) -> bool:
	for bone_name in REQUIRED_BONES:
		if skeleton.find_bone(bone_name) < 0:
			_fail("rigged Mara skeleton is missing bone: %s" % bone_name)
			return false
	return true


func _has_required_meshes(root_node: Node) -> bool:
	for mesh_name in REQUIRED_MESH_NAMES:
		var mesh := _find_mesh(root_node, mesh_name)
		if mesh == null:
			_fail("rigged Mara GLB is missing mesh: %s" % mesh_name)
			return false
		if mesh.mesh == null:
			_fail("rigged Mara mesh has no Mesh resource: %s" % mesh_name)
			return false
	return true


func _check_face_mask_density(root_node: Node) -> bool:
	var face_mask := _find_mesh(root_node, "mara_rigged_skin_face_mask")
	if face_mask == null or face_mask.mesh == null:
		_fail("rigged Mara dense face mask is missing")
		return false
	var arrays := face_mask.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.size() >= 240:
		return true
	_fail("rigged Mara face mask is too low-density for premium facial shaping")
	return false


func _check_player_rig_can_drive(imported: Node3D, skeleton: Skeleton3D) -> bool:
	var rig := _instantiate_player_rig()
	if rig == null:
		return false
	var shoulder := rig.get_node_or_null("Hips/ShoulderL") as Node3D
	if shoulder == null:
		_fail("player rig is missing shoulder source for rigged Mara drive check")
		return false
	return _check_shoulder_drive(imported, skeleton, rig, shoulder)


func _instantiate_player_rig() -> Node:
	var player_scene := load(PLAYER_SCENE) as PackedScene
	if player_scene == null:
		_fail("could not load player scene for rigged Mara drive check")
		return null
	var player := player_scene.instantiate()
	if player == null:
		_fail("could not instantiate player scene for rigged Mara drive check")
		return null
	root.add_child(player)
	var rig := player.get_node_or_null("Rig")
	if rig == null:
		_fail("player scene is missing CharacterAnimator rig")
	return rig


func _check_shoulder_drive(
	imported: Node3D, skeleton: Skeleton3D, rig: Node, shoulder: Node3D
) -> bool:
	var bone_index := skeleton.find_bone("MaraShoulderL")
	if bone_index < 0:
		_fail("rigged Mara skeleton is missing drive-check shoulder bone")
		return false
	var before := skeleton.get_bone_pose_rotation(bone_index)
	shoulder.rotation.x = 0.45
	ImportedMaraProxyBinder.drive_rigged(imported, rig)
	var after := skeleton.get_bone_pose_rotation(bone_index)
	if not after.is_equal_approx(before):
		return true
	_fail("rigged Mara skeleton did not receive player rig animation")
	return false


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == mesh_name:
		return node
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error("player_mara_rigged_asset: %s" % message)
	quit(1)
