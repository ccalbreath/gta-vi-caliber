extends SceneTree
## Runtime guard for the playable Mara integration. This catches lifecycle bugs
## that unit tests cannot see, such as deferred GLB attachment under the wrong
## part of the animated rig.

const PLAYER_SCENE := "res://scenes/player/player.tscn"

var _frames := 0
var _player: Node
var _camera: Camera3D
var _imported: Node3D = null
var _torso: MeshInstance3D = null
var _checked_front := false
var _checked_front_side := false
var _checked_rear := false


func _initialize() -> void:
	var scene := load(PLAYER_SCENE) as PackedScene
	if scene == null:
		_fail("could not load player scene")
		return
	_player = scene.instantiate()
	root.add_child(_player)
	_camera = Camera3D.new()
	_camera.name = "MaraRuntimeCamera"
	root.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 1.12, -4.2), Vector3(0.0, 0.98, 0.0), Vector3.UP)
	_camera.make_current()


func _process(_delta: float) -> bool:
	_frames += 1
	var done := false
	if _frames < 3:
		pass
	elif not _checked_front:
		done = not _check_front_view()
		if not done:
			_checked_front = true
			_camera.look_at_from_position(
				Vector3(4.2, 1.12, 0.0), Vector3(0.0, 0.98, 0.0), Vector3.UP
			)
			_camera.make_current()
	elif _frames < 8:
		pass
	elif not _checked_front_side:
		done = not _check_front_side_hysteresis()
		if not done:
			_checked_front_side = true
			_camera.look_at_from_position(
				Vector3(0.0, 1.12, 4.2), Vector3(0.0, 0.98, 0.0), Vector3.UP
			)
			_camera.make_current()
	elif _frames < 13:
		pass
	elif not _checked_rear:
		done = not _check_rear_view()
		if not done:
			_checked_rear = true
			_camera.look_at_from_position(
				Vector3(4.2, 1.12, 0.0), Vector3(0.0, 0.98, 0.0), Vector3.UP
			)
			_camera.make_current()
	elif _frames < 18:
		pass
	elif not _check_rear_side_hysteresis():
		done = true
	else:
		done = _check_animated_attachment()
	return done


func _check_animated_attachment() -> bool:
	var hips := _player.get_node_or_null("Rig/Hips") as Node3D
	var head := _player.get_node_or_null("Rig/Hips/Head") as Node3D
	var pelvis := _player.get_node_or_null("Rig/Hips/Pelvis") as Node3D
	var torso := _player.get_node_or_null("Rig/Hips/Torso") as Node3D
	var shoulder_l := _player.get_node_or_null("Rig/Hips/ShoulderL") as Node3D
	var body := _player.get_node_or_null("Rig/Body")
	var rig := _player.get_node_or_null("Rig") as CharacterAnimator
	if (
		hips == null
		or head == null
		or pelvis == null
		or torso == null
		or shoulder_l == null
		or body == null
		or rig == null
	):
		_fail("player rig hierarchy is incomplete")
		return true
	var before_y := _imported.global_position.y
	rig.animate(Vector3(5.0, 0.0, 0.0), true, 0.0, false, 0.1)
	if not _check_after_animated_motion(before_y, body, rig, pelvis, torso, shoulder_l, head):
		return true
	if not _check_idle_life(hips, head, rig):
		return true
	if not _check_turn_lean(hips, rig):
		return true
	if not _check_landing_compression(hips, rig):
		return true
	print("player_mara_runtime: OK")
	quit(0)
	return true


func _check_after_animated_motion(
	before_y: float,
	body: Node,
	rig: CharacterAnimator,
	pelvis: Node3D,
	torso: Node3D,
	shoulder_l: Node3D,
	head: Node3D
) -> bool:
	if is_equal_approx(_imported.global_position.y, before_y):
		_fail("imported Mara mesh did not inherit animated hip motion")
		return false
	return (
		_check_rigged_mara_binding(body, rig)
		and _check_secondary_motion(pelvis, torso, shoulder_l, head)
		and _check_premium_stride_detail(torso)
		and _check_mara_gear_motion_and_shape(body)
		and _check_face_life(body)
		and _check_mara_material_quality()
	)


func _check_rigged_mara_binding(body: Node, rig: CharacterAnimator) -> bool:
	var skeleton := _find_skeleton(_imported)
	var jacket := _find_mesh(_imported, "mara_rigged_jacket")
	var head := _find_mesh(_imported, "mara_rigged_head")
	var boot := _find_mesh(_imported, "mara_rigged_boot_l")
	var replacement_arm := (
		_player.get_node_or_null("Rig/Hips/ShoulderL/mara_three_replacement_upper_arm_l")
		as MeshInstance3D
	)
	var replacement_cap := (
		_player.get_node_or_null("Rig/Hips/ShoulderL/mara_three_replacement_shoulder_cap_l")
		as MeshInstance3D
	)
	var shoulder_slope := (
		_player.get_node_or_null("Rig/Hips/ShoulderL/mara_three_replacement_shoulder_slope_l")
		as MeshInstance3D
	)
	var sleeve_panel := (
		_player.get_node_or_null(
			"Rig/Hips/ShoulderL/mara_three_replacement_upper_arm_sleeve_panel_l"
		)
		as MeshInstance3D
	)
	var forearm_cuff := (
		_player.get_node_or_null("Rig/Hips/ShoulderL/Elbow/mara_three_replacement_forearm_cuff_l")
		as MeshInstance3D
	)
	var original_arm := _find_mesh(_imported, "mara_rigged_upper_arm_l")
	if skeleton == null or jacket == null or head == null or boot == null:
		_fail("Three.js rigged Mara skeleton or skinned meshes are missing")
		return false
	if (
		replacement_arm == null
		or replacement_cap == null
		or shoulder_slope == null
		or sleeve_panel == null
		or forearm_cuff == null
		or original_arm == null
	):
		_fail("Three.js rigged Mara replacement arms are missing")
		return false
	var details_ok := _check_replacement_arm_detail_materials(
		shoulder_slope, sleeve_panel, forearm_cuff
	)
	if not original_arm.get_meta("mara_rigged_arm_skin_hidden", false):
		_fail("malformed imported Mara arm skin was not hidden")
		details_ok = false
	if not details_ok:
		return false
	var shoulder_index := skeleton.find_bone("MaraShoulderL")
	var head_index := skeleton.find_bone("MaraHead")
	if shoulder_index < 0 or head_index < 0:
		_fail("Three.js rigged Mara skeleton is missing animated bones")
		return false
	var shoulder_before := skeleton.get_bone_pose_rotation(shoulder_index)
	var head_before := skeleton.get_bone_pose_rotation(head_index)
	var replacement_before := replacement_arm.global_transform
	rig.animate(Vector3(7.0, 0.0, 0.0), true, 0.0, false, 0.12)
	body.call("_process", 0.016)
	var arm_moved := not skeleton.get_bone_pose_rotation(shoulder_index).is_equal_approx(
		shoulder_before
	)
	var head_moved := not skeleton.get_bone_pose_rotation(head_index).is_equal_approx(head_before)
	var replacement_moved := not replacement_arm.global_transform.is_equal_approx(
		replacement_before
	)
	if arm_moved and head_moved and replacement_moved:
		return true
	_fail("Three.js rigged Mara skeleton or replacement arms did not inherit animation")
	return false


func _check_replacement_arm_detail_materials(
	shoulder_slope: MeshInstance3D, sleeve_panel: MeshInstance3D, forearm_cuff: MeshInstance3D
) -> bool:
	var shoulder_slope_mat := shoulder_slope.material_override as StandardMaterial3D
	var sleeve_panel_mat := sleeve_panel.material_override as StandardMaterial3D
	var forearm_cuff_mat := forearm_cuff.material_override as StandardMaterial3D
	if (
		shoulder_slope_mat != null
		and sleeve_panel_mat != null
		and forearm_cuff_mat != null
		and _check_jacket_material(shoulder_slope_mat)
		and _check_jacket_material(sleeve_panel_mat)
		and _check_jacket_material(forearm_cuff_mat)
	):
		return true
	_fail("Three.js rigged Mara replacement arm detail materials are missing")
	return false


func _check_idle_life(hips: Node3D, head: Node3D, rig: CharacterAnimator) -> bool:
	rig.animate(Vector3.ZERO, true, 0.0, false, 0.25)
	var first_hips := hips.position
	var first_head_pitch := head.rotation.x
	rig.animate(Vector3.ZERO, true, 0.0, false, 0.25)
	var hips_moved := hips.position.distance_to(first_hips) > 0.0001
	var head_moved := absf(head.rotation.x - first_head_pitch) > 0.0001
	if hips_moved and head_moved:
		return true
	_fail("playable Mara idle pose did not breathe or shift weight")
	return false


func _check_secondary_motion(
	pelvis: Node3D, torso: Node3D, shoulder_l: Node3D, head: Node3D
) -> bool:
	if is_zero_approx(absf(head.rotation.x) + absf(head.rotation.z)):
		_fail("playable Mara head did not receive secondary motion")
		return false
	return _check_stride_twist(pelvis, torso, shoulder_l, head)


func _check_premium_stride_detail(torso: Node3D) -> bool:
	var shoulder_l := _player.get_node_or_null("Rig/Hips/ShoulderL") as Node3D
	var shoulder_r := _player.get_node_or_null("Rig/Hips/ShoulderR") as Node3D
	if shoulder_l == null or shoulder_r == null:
		_fail("playable Mara shoulders are missing for premium stride check")
		return false
	var shoulder_delta := absf(shoulder_l.position.y - shoulder_r.position.y)
	if shoulder_delta > 0.001 and absf(torso.rotation.x) > 0.001:
		return true
	_fail("playable Mara stride did not add shoulder lift and chest compression")
	return false


func _check_turn_lean(hips: Node3D, rig: CharacterAnimator) -> bool:
	rig.animate(Vector3(-5.0, 0.0, 0.0), true, 0.0, false, 0.1)
	if absf(hips.rotation.z) > 0.001:
		return true
	_fail("playable Mara did not lean into turn")
	return false


func _check_landing_compression(hips: Node3D, rig: CharacterAnimator) -> bool:
	var before_y := hips.position.y
	rig.animate(Vector3.ZERO, false, -10.0, false, 0.05)
	rig.animate(Vector3.ZERO, true, 0.0, false, 0.016)
	if hips.position.y < before_y - 0.001:
		return true
	_fail("playable Mara did not compress on landing")
	return false


func _check_stride_twist(pelvis: Node3D, torso: Node3D, shoulder_l: Node3D, head: Node3D) -> bool:
	var twist_strength := (
		absf(torso.rotation.y)
		+ absf(shoulder_l.rotation.y)
		+ absf(pelvis.rotation.y)
		+ absf(head.rotation.y)
	)
	if twist_strength > 0.001 and signf(torso.rotation.y) == signf(shoulder_l.rotation.y):
		return true
	_fail("playable Mara stride did not apply upper-body twist")
	return false


func _check_mara_gear_motion_and_shape(body: Node) -> bool:
	return (
		_check_mara_soft_motion(body)
		and _check_mara_rounded_gear()
		and _check_mara_foot_articulation()
	)


func _check_mara_soft_motion(body: Node) -> bool:
	var rig := _player.get_node_or_null("Rig")
	if rig != null:
		body.call("_set_procedural_visible", rig, true)
		var hips := _player.get_node_or_null("Rig/Hips") as Node3D
		var torso := _player.get_node_or_null("Rig/Hips/Torso") as Node3D
		if hips != null:
			hips.position.x = 0.05
			hips.rotation.z = 0.04
		if torso != null:
			torso.rotation.y = 0.06
	var pendant := _player.get_node_or_null("Rig/Hips/MaraPendant") as Node3D
	var strap := _player.get_node_or_null("Rig/Hips/MaraMessengerStrap") as Node3D
	var hair := _player.get_node_or_null("Rig/Hips/Head/MaraRearHairMass") as Node3D
	if pendant == null or strap == null or hair == null:
		_fail("playable Mara soft-motion nodes are missing")
		return false
	if (
		not pendant.get_meta("mara_soft_motion", false)
		or not strap.get_meta("mara_soft_motion", false)
	):
		_fail("playable Mara gear is not marked for soft motion")
		return false
	var before_position := pendant.position
	var before_rotation := strap.rotation
	body.call("_update_mara_soft_motion", 0.1)
	var pendant_moved := pendant.position.distance_to(before_position) > 0.0001
	var strap_rotated := strap.rotation.distance_to(before_rotation) > 0.0001
	if pendant_moved and strap_rotated and hair.get_meta("mara_soft_motion", false):
		return true
	_fail("playable Mara soft-motion gear did not react to stride")
	return false


func _check_mara_rounded_gear() -> bool:
	var rounded_paths: PackedStringArray = [
		"Rig/Hips/MaraMessengerStrap",
		"Rig/Hips/MaraMessengerStrapBack",
		"Rig/Hips/MaraPendantCord",
		"Rig/Hips/HipL/MaraThighUtilityBand",
		"Rig/Hips/ShoulderL/Elbow/MaraWristWrap",
	]
	for path in rounded_paths:
		var mesh := _player.get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			_fail("playable Mara rounded gear node is missing: %s" % path)
			return false
		if mesh.mesh is BoxMesh:
			_fail("playable Mara rounded gear still uses a box mesh: %s" % path)
			return false
	return true


func _check_mara_foot_articulation() -> bool:
	var ankle_l := _player.get_node_or_null("Rig/Hips/HipL/Knee/Ankle") as Node3D
	var ankle_r := _player.get_node_or_null("Rig/Hips/HipR/Knee/Ankle") as Node3D
	if ankle_l == null or ankle_r == null:
		_fail("playable Mara ankle nodes are missing")
		return false
	if is_zero_approx(absf(ankle_l.rotation.y) + absf(ankle_l.rotation.z)):
		_fail("playable Mara left foot did not receive toe-out/bank")
		return false
	if signf(ankle_l.rotation.y) == signf(ankle_r.rotation.y):
		_fail("playable Mara feet do not mirror toe-out")
		return false
	return true


func _check_front_view() -> bool:
	_camera.make_current()
	_imported = _player.get_node_or_null("Rig/Hips/MaraImportedMesh") as Node3D
	if _imported == null:
		_fail("MaraImportedMesh was not attached under Rig/Hips")
		return false
	if _imported.get_node_or_null("MaraRiggedProxy") == null:
		_fail("MaraImportedMesh is not using the Three.js-authored rigged asset")
		return false
	if not _has_visible_mesh(_imported):
		_fail("front camera did not show imported Mara mesh")
		return false
	if not _imported_casts_shadows():
		_fail("front camera did not enable imported Mara shadows")
		return false
	_torso = _player.get_node_or_null("Rig/Hips/Torso") as MeshInstance3D
	if _torso != null and _torso.visible:
		_fail("procedural body is still visible over imported Mara front mesh")
		return false
	return true


func _check_front_side_hysteresis() -> bool:
	_camera.make_current()
	if _imported != null and not _has_visible_mesh(_imported):
		_fail("side camera lost imported Mara before rear threshold")
		return false
	if _torso != null and _torso.visible:
		_fail("side camera restored procedural body before rear threshold")
		return false
	return true


func _check_rear_view() -> bool:
	_camera.make_current()
	if not _check_rear_mesh_switch():
		return false
	if not _has_full_body_mara_gear():
		_fail("rear gameplay Mara rig is missing full-body hero gear")
		return false
	if not _check_procedural_shadow_budget():
		return false
	return _check_procedural_cosmetic_lod()


func _check_rear_mesh_switch() -> bool:
	if _imported != null and _has_visible_mesh(_imported):
		_fail("rear gameplay camera still shows imported Mara rear shell")
		return false
	if _imported_casts_shadows():
		_fail("rear gameplay camera still lets hidden imported Mara cast shadows")
		return false
	if _torso != null and not _torso.visible:
		_fail("rear gameplay camera did not restore procedural Mara body")
		return false
	return true


func _check_rear_side_hysteresis() -> bool:
	_camera.make_current()
	if _imported != null and _has_visible_mesh(_imported):
		_fail("side camera re-shown imported Mara before front threshold")
		return false
	if _torso != null and not _torso.visible:
		_fail("side camera hid procedural body before front threshold")
		return false
	return true


func _fail(message: String) -> void:
	push_error("player_mara_runtime: %s" % message)
	quit(1)


func _has_visible_mesh(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
		return true
	for child in node.get_children():
		if _has_visible_mesh(child):
			return true
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


func _imported_casts_shadows() -> bool:
	return _has_shadow_casting_mesh(_imported)


func _has_shadow_casting_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	for child in node.get_children():
		if _has_shadow_casting_mesh(child):
			return true
	return false


func _has_full_body_mara_gear() -> bool:
	var required: PackedStringArray = [
		"Rig/Hips/MaraSideHolster",
		"Rig/Hips/HipL/MaraThighUtilityBand",
		"Rig/Hips/HipR/MaraKneePad",
		"Rig/Hips/HipL/Knee/Ankle/MaraBootSole",
		"Rig/Hips/ShoulderL/Elbow/MaraWristWrap",
		"Rig/Hips/ShoulderR/Elbow/MaraGloveKnuckles",
		"Rig/Hips/Head/MaraSideHairLock",
		"Rig/Hips/Head/MaraBlinkLid",
	]
	for path in required:
		if _player.get_node_or_null(path) == null:
			return false
	return true


func _check_face_life(body: Node) -> bool:
	var lid := _player.get_node_or_null("Rig/Hips/Head/MaraBlinkLid") as MeshInstance3D
	if lid == null:
		_fail("playable Mara face is missing blink eyelids")
		return false
	body.set("_blink_t", 0.0)
	var before := lid.scale.y
	body.call("_process", 0.08)
	if is_equal_approx(lid.scale.y, before):
		_fail("playable Mara blink eyelids did not animate")
		return false
	return true


func _check_mara_material_quality() -> bool:
	var head := _player.get_node_or_null("Rig/Hips/Head") as MeshInstance3D
	var jacket := _player.get_node_or_null("Rig/Hips/MaraCroppedJacket") as MeshInstance3D
	var strap := _player.get_node_or_null("Rig/Hips/MaraMessengerStrap") as MeshInstance3D
	var hair := _player.get_node_or_null("Rig/Hips/Head/MaraRearHairMass") as MeshInstance3D
	if head == null or jacket == null or strap == null or hair == null:
		_fail("playable Mara material-quality nodes are missing")
		return false
	var skin := head.material_override as StandardMaterial3D
	var jacket_mat := jacket.material_override as StandardMaterial3D
	var strap_mat := strap.material_override as StandardMaterial3D
	var hair_mat := hair.material_override as StandardMaterial3D
	if skin == null or jacket_mat == null or strap_mat == null or hair_mat == null:
		_fail("playable Mara material-quality surfaces are missing")
		return false
	return (
		_check_skin_material(skin)
		and _check_jacket_material(jacket_mat)
		and _check_leather_material(strap_mat)
		and _check_hair_material(hair_mat)
		and _check_imported_mara_material_quality()
	)


func _check_imported_mara_material_quality() -> bool:
	var head := _find_mesh(_imported, "mara_rigged_head")
	var face_mask := _find_mesh(_imported, "mara_rigged_skin_face_mask")
	var jacket := _find_mesh(_imported, "mara_rigged_jacket")
	var jacket_front_panel := _find_mesh(_imported, "mara_rigged_jacket_front_panel_l")
	var shirt_draped_front := _find_mesh(_imported, "mara_rigged_shirt_draped_front")
	var trouser_front_panel := _find_mesh(_imported, "mara_rigged_trouser_front_panel_l")
	var strap := _find_mesh(_imported, "mara_rigged_cross_body_strap")
	var pendant := _find_mesh(_imported, "mara_rigged_pendant")
	var belt := _find_mesh(_imported, "mara_rigged_belt")
	var eye := _find_mesh(_imported, "mara_rigged_eye_l")
	var eye_socket_shadow := _find_mesh(_imported, "mara_rigged_eye_socket_shadow_l")
	var eye_sclera := _find_mesh(_imported, "mara_rigged_eye_sclera_l")
	var eye_iris := _find_mesh(_imported, "mara_rigged_eye_iris_l")
	var mouth := _find_mesh(_imported, "mara_rigged_mouth")
	var eye_highlight := _find_mesh(_imported, "mara_rigged_eye_highlight_l")
	var cornea_glint := _find_mesh(_imported, "mara_rigged_cornea_glint_l")
	var lip := _find_mesh(_imported, "mara_rigged_mouth_upper_lip")
	var cheek := _find_mesh(_imported, "mara_rigged_cheek_l")
	var upper_eyelid := _find_mesh(_imported, "mara_rigged_upper_eyelid_l")
	var lid_crease := _find_mesh(_imported, "mara_rigged_lid_crease_l")
	var lash := _find_mesh(_imported, "mara_rigged_lash_l")
	var brow_ridge := _find_mesh(_imported, "mara_rigged_skin_brow_ridge_l")
	var under_eye_shadow := _find_mesh(_imported, "mara_rigged_skin_under_eye_shadow_l")
	var nostril := _find_mesh(_imported, "mara_rigged_nostril_l")
	var nasolabial_fold := _find_mesh(_imported, "mara_rigged_skin_nasolabial_fold_l")
	var temple := _find_mesh(_imported, "mara_rigged_skin_temple_l")
	var mouth_corner := _find_mesh(_imported, "mara_rigged_mouth_corner_l")
	var mouth_soft_seam := _find_mesh(_imported, "mara_rigged_mouth_soft_seam")
	var philtrum := _find_mesh(_imported, "mara_rigged_philtrum_l")
	var under_lip_plane := _find_mesh(_imported, "mara_rigged_skin_under_lip_plane")
	var chin := _find_mesh(_imported, "mara_rigged_chin")
	var jaw_shadow := _find_mesh(_imported, "mara_rigged_jaw_shadow_l")
	var hair_crown := _find_mesh(_imported, "mara_rigged_hair_crown")
	var hair_forelock := _find_mesh(_imported, "mara_rigged_hair_forelock")
	var hair_sideburn := _find_mesh(_imported, "mara_rigged_hair_sideburn_l")
	var hair_parting_line := _find_mesh(_imported, "mara_rigged_hair_parting_line")
	var hairline_wisps := _find_mesh(_imported, "mara_rigged_hairline_wisps_l")
	var hair_strand := _find_mesh(_imported, "mara_rigged_hair_strand_l")
	var hair_flyaway := _find_mesh(_imported, "mara_rigged_hair_flyaway_l")
	var hair_nape_layer := _find_mesh(_imported, "mara_rigged_hair_nape_layer_l")
	var collar := _find_mesh(_imported, "mara_rigged_jacket_collar_l")
	var zipper := _find_mesh(_imported, "mara_rigged_jacket_zipper")
	var zipper_pull := _find_mesh(_imported, "mara_rigged_jacket_zipper_pull")
	var jacket_seam := _find_mesh(_imported, "mara_rigged_jacket_seam_l")
	var jacket_topstitch := _find_mesh(_imported, "mara_rigged_jacket_topstitch_l")
	var sleeve_wrinkle := _find_mesh(_imported, "mara_rigged_sleeve_wrinkle_l")
	var shirt_fold := _find_mesh(_imported, "mara_rigged_shirt_fold_l")
	var trouser_crease := _find_mesh(_imported, "mara_rigged_trouser_crease_l")
	var knee_fold := _find_mesh(_imported, "mara_rigged_knee_fold_l")
	var thigh_side_seam := _find_mesh(_imported, "mara_rigged_thigh_side_seam_l")
	var boot_toe := _find_mesh(_imported, "mara_rigged_boot_toe_l")
	var boot_rivet := _find_mesh(_imported, "mara_rigged_boot_rivet_outer_l")
	var belt_buckle := _find_mesh(_imported, "mara_rigged_belt_buckle")
	var strap_buckle := _find_mesh(_imported, "mara_rigged_strap_buckle")
	var finger := _find_mesh(_imported, "mara_rigged_index_finger_l")
	var palm_pad := _find_mesh(_imported, "mara_rigged_palm_pad_l")
	var knuckle := _find_mesh(_imported, "mara_rigged_index_knuckle_l")
	var nail := _find_mesh(_imported, "mara_rigged_index_nail_l")
	if (
		head == null
		or face_mask == null
		or jacket == null
		or jacket_front_panel == null
		or shirt_draped_front == null
		or trouser_front_panel == null
		or strap == null
		or pendant == null
		or belt == null
		or eye == null
		or eye_socket_shadow == null
		or eye_sclera == null
		or eye_iris == null
		or mouth == null
		or eye_highlight == null
		or cornea_glint == null
		or lip == null
		or cheek == null
		or upper_eyelid == null
		or lid_crease == null
		or lash == null
		or brow_ridge == null
		or under_eye_shadow == null
		or nostril == null
		or nasolabial_fold == null
		or temple == null
		or mouth_corner == null
		or mouth_soft_seam == null
		or philtrum == null
		or under_lip_plane == null
		or chin == null
		or jaw_shadow == null
		or hair_crown == null
		or hair_forelock == null
		or hair_sideburn == null
		or hair_parting_line == null
		or hairline_wisps == null
		or hair_strand == null
		or hair_flyaway == null
		or hair_nape_layer == null
		or collar == null
		or zipper == null
		or zipper_pull == null
		or jacket_seam == null
		or jacket_topstitch == null
		or sleeve_wrinkle == null
		or shirt_fold == null
		or trouser_crease == null
		or knee_fold == null
		or thigh_side_seam == null
		or boot_toe == null
		or boot_rivet == null
		or belt_buckle == null
		or strap_buckle == null
		or finger == null
		or palm_pad == null
		or knuckle == null
		or nail == null
	):
		_fail("imported rigged Three.js Mara material-quality nodes are missing")
		return false
	var skin := head.material_override as StandardMaterial3D
	var face_mask_mat := face_mask.material_override as StandardMaterial3D
	var jacket_mat := jacket.material_override as StandardMaterial3D
	var jacket_front_panel_mat := jacket_front_panel.material_override as StandardMaterial3D
	var shirt_draped_front_mat := shirt_draped_front.material_override as StandardMaterial3D
	var trouser_front_panel_mat := trouser_front_panel.material_override as StandardMaterial3D
	var strap_mat := strap.material_override as StandardMaterial3D
	var pendant_mat := pendant.material_override as StandardMaterial3D
	var belt_mat := belt.material_override as StandardMaterial3D
	var eye_mat := eye.material_override as StandardMaterial3D
	var eye_socket_shadow_mat := eye_socket_shadow.material_override as StandardMaterial3D
	var eye_sclera_mat := eye_sclera.material_override as StandardMaterial3D
	var eye_iris_mat := eye_iris.material_override as StandardMaterial3D
	var mouth_mat := mouth.material_override as StandardMaterial3D
	var eye_highlight_mat := eye_highlight.material_override as StandardMaterial3D
	var cornea_glint_mat := cornea_glint.material_override as StandardMaterial3D
	var lip_mat := lip.material_override as StandardMaterial3D
	var cheek_mat := cheek.material_override as StandardMaterial3D
	var upper_eyelid_mat := upper_eyelid.material_override as StandardMaterial3D
	var lid_crease_mat := lid_crease.material_override as StandardMaterial3D
	var lash_mat := lash.material_override as StandardMaterial3D
	var brow_ridge_mat := brow_ridge.material_override as StandardMaterial3D
	var under_eye_shadow_mat := under_eye_shadow.material_override as StandardMaterial3D
	var nostril_mat := nostril.material_override as StandardMaterial3D
	var nasolabial_fold_mat := nasolabial_fold.material_override as StandardMaterial3D
	var temple_mat := temple.material_override as StandardMaterial3D
	var mouth_corner_mat := mouth_corner.material_override as StandardMaterial3D
	var mouth_soft_seam_mat := mouth_soft_seam.material_override as StandardMaterial3D
	var philtrum_mat := philtrum.material_override as StandardMaterial3D
	var under_lip_plane_mat := under_lip_plane.material_override as StandardMaterial3D
	var chin_mat := chin.material_override as StandardMaterial3D
	var jaw_shadow_mat := jaw_shadow.material_override as StandardMaterial3D
	var hair_crown_mat := hair_crown.material_override as StandardMaterial3D
	var hair_forelock_mat := hair_forelock.material_override as StandardMaterial3D
	var hair_sideburn_mat := hair_sideburn.material_override as StandardMaterial3D
	var hair_parting_line_mat := hair_parting_line.material_override as StandardMaterial3D
	var hairline_wisps_mat := hairline_wisps.material_override as StandardMaterial3D
	var hair_strand_mat := hair_strand.material_override as StandardMaterial3D
	var hair_flyaway_mat := hair_flyaway.material_override as StandardMaterial3D
	var hair_nape_layer_mat := hair_nape_layer.material_override as StandardMaterial3D
	var collar_mat := collar.material_override as StandardMaterial3D
	var zipper_mat := zipper.material_override as StandardMaterial3D
	var zipper_pull_mat := zipper_pull.material_override as StandardMaterial3D
	var jacket_seam_mat := jacket_seam.material_override as StandardMaterial3D
	var jacket_topstitch_mat := jacket_topstitch.material_override as StandardMaterial3D
	var sleeve_wrinkle_mat := sleeve_wrinkle.material_override as StandardMaterial3D
	var shirt_fold_mat := shirt_fold.material_override as StandardMaterial3D
	var trouser_crease_mat := trouser_crease.material_override as StandardMaterial3D
	var knee_fold_mat := knee_fold.material_override as StandardMaterial3D
	var thigh_side_seam_mat := thigh_side_seam.material_override as StandardMaterial3D
	var boot_toe_mat := boot_toe.material_override as StandardMaterial3D
	var boot_rivet_mat := boot_rivet.material_override as StandardMaterial3D
	var belt_buckle_mat := belt_buckle.material_override as StandardMaterial3D
	var strap_buckle_mat := strap_buckle.material_override as StandardMaterial3D
	var finger_mat := finger.material_override as StandardMaterial3D
	var palm_pad_mat := palm_pad.material_override as StandardMaterial3D
	var knuckle_mat := knuckle.material_override as StandardMaterial3D
	var nail_mat := nail.material_override as StandardMaterial3D
	if (
		skin == null
		or face_mask_mat == null
		or jacket_mat == null
		or jacket_front_panel_mat == null
		or shirt_draped_front_mat == null
		or trouser_front_panel_mat == null
		or strap_mat == null
		or pendant_mat == null
		or belt_mat == null
		or eye_mat == null
		or eye_socket_shadow_mat == null
		or eye_sclera_mat == null
		or eye_iris_mat == null
		or mouth_mat == null
		or eye_highlight_mat == null
		or cornea_glint_mat == null
		or lip_mat == null
		or cheek_mat == null
		or upper_eyelid_mat == null
		or lid_crease_mat == null
		or lash_mat == null
		or brow_ridge_mat == null
		or under_eye_shadow_mat == null
		or nostril_mat == null
		or nasolabial_fold_mat == null
		or temple_mat == null
		or mouth_corner_mat == null
		or mouth_soft_seam_mat == null
		or philtrum_mat == null
		or under_lip_plane_mat == null
		or chin_mat == null
		or jaw_shadow_mat == null
		or hair_crown_mat == null
		or hair_forelock_mat == null
		or hair_sideburn_mat == null
		or hair_parting_line_mat == null
		or hairline_wisps_mat == null
		or hair_strand_mat == null
		or hair_flyaway_mat == null
		or hair_nape_layer_mat == null
		or collar_mat == null
		or zipper_mat == null
		or zipper_pull_mat == null
		or jacket_seam_mat == null
		or jacket_topstitch_mat == null
		or sleeve_wrinkle_mat == null
		or shirt_fold_mat == null
		or trouser_crease_mat == null
		or knee_fold_mat == null
		or thigh_side_seam_mat == null
		or boot_toe_mat == null
		or boot_rivet_mat == null
		or belt_buckle_mat == null
		or strap_buckle_mat == null
		or finger_mat == null
		or palm_pad_mat == null
		or knuckle_mat == null
		or nail_mat == null
	):
		_fail("imported Three.js Mara material overrides are missing")
		return false
	return (
		_check_skin_material(skin)
		and _check_skin_material(face_mask_mat)
		and _check_jacket_material(jacket_mat)
		and _check_jacket_material(jacket_front_panel_mat)
		and _check_jacket_material(shirt_draped_front_mat)
		and _check_jacket_material(trouser_front_panel_mat)
		and _check_leather_material(strap_mat)
		and _check_leather_material(belt_mat)
		and _check_eye_material(eye_mat)
		and _check_eye_material(eye_iris_mat)
		and _check_eye_material(eye_highlight_mat)
		and _check_eye_material(cornea_glint_mat)
		and String(eye_sclera_mat.get_meta("mara_imported_surface_profile", "")) == "sclera"
		and (
			String(eye_socket_shadow_mat.get_meta("mara_imported_surface_profile", ""))
			== "skin_shadow"
		)
		and _check_skin_material(cheek_mat)
		and _check_skin_material(upper_eyelid_mat)
		and String(lid_crease_mat.get_meta("mara_imported_surface_profile", "")) == "skin_shadow"
		and _check_skin_material(brow_ridge_mat)
		and _check_skin_material(under_eye_shadow_mat)
		and _check_skin_material(nasolabial_fold_mat)
		and _check_skin_material(temple_mat)
		and _check_skin_material(under_lip_plane_mat)
		and _check_skin_material(chin_mat)
		and _check_skin_material(jaw_shadow_mat)
		and _check_jacket_material(collar_mat)
		and _check_jacket_material(jacket_seam_mat)
		and _check_jacket_material(jacket_topstitch_mat)
		and _check_jacket_material(sleeve_wrinkle_mat)
		and _check_jacket_material(shirt_fold_mat)
		and _check_jacket_material(trouser_crease_mat)
		and _check_jacket_material(knee_fold_mat)
		and _check_jacket_material(thigh_side_seam_mat)
		and _check_leather_material(boot_toe_mat)
		and _check_skin_material(finger_mat)
		and _check_skin_material(palm_pad_mat)
		and _check_skin_material(knuckle_mat)
		and _check_hair_material(lash_mat)
		and _check_hair_material(hair_crown_mat)
		and _check_hair_material(hair_forelock_mat)
		and _check_hair_material(hair_sideburn_mat)
		and (
			String(hair_parting_line_mat.get_meta("mara_imported_surface_profile", ""))
			== "skin_shadow"
		)
		and _check_hair_material(hairline_wisps_mat)
		and _check_hair_material(hair_strand_mat)
		and _check_hair_material(hair_flyaway_mat)
		and _check_hair_material(hair_nape_layer_mat)
		and String(mouth_mat.get_meta("mara_imported_surface_profile", "")) == "mouth"
		and String(lip_mat.get_meta("mara_imported_surface_profile", "")) == "mouth"
		and String(nostril_mat.get_meta("mara_imported_surface_profile", "")) == "mouth"
		and String(mouth_corner_mat.get_meta("mara_imported_surface_profile", "")) == "mouth"
		and String(nail_mat.get_meta("mara_imported_surface_profile", "")) == "sclera"
		and (
			String(mouth_soft_seam_mat.get_meta("mara_imported_surface_profile", ""))
			== "skin_shadow"
		)
		and String(philtrum_mat.get_meta("mara_imported_surface_profile", "")) == "skin_shadow"
		and pendant_mat.metallic > 0.5
		and zipper_mat.metallic > 0.5
		and zipper_pull_mat.metallic > 0.5
		and boot_rivet_mat.metallic > 0.5
		and belt_buckle_mat.metallic > 0.5
		and strap_buckle_mat.metallic > 0.5
	)


func _check_skin_material(mat: StandardMaterial3D) -> bool:
	if (
		mat.subsurf_scatter_enabled
		and mat.clearcoat_enabled
		and mat.normal_enabled
		and mat.albedo_texture != null
	):
		return true
	_fail("playable Mara skin material is missing premium skin shading and albedo breakup")
	return false


func _check_jacket_material(mat: StandardMaterial3D) -> bool:
	if mat.normal_enabled and mat.uv1_triplanar and mat.albedo_texture != null:
		return true
	_fail("playable Mara jacket material is missing triplanar fabric detail and albedo breakup")
	return false


func _check_leather_material(mat: StandardMaterial3D) -> bool:
	if (
		mat.clearcoat_enabled
		and mat.normal_enabled
		and mat.uv1_triplanar
		and mat.albedo_texture != null
	):
		return true
	_fail("playable Mara leather material is missing worn-sheen detail and albedo breakup")
	return false


func _check_hair_material(mat: StandardMaterial3D) -> bool:
	if (
		mat.rim_enabled
		and (
			String(mat.get_meta("mara_surface_profile", "")) == "hair"
			or String(mat.get_meta("mara_imported_surface_profile", "")) == "hair"
		)
	):
		return true
	_fail("playable Mara hair material is missing silhouette shading")
	return false


func _check_eye_material(mat: StandardMaterial3D) -> bool:
	if mat.clearcoat_enabled and mat.clearcoat > 0.5 and mat.emission_enabled:
		return true
	_fail("imported rigged Mara eyes are missing glossy live-eye shading")
	return false


func _check_procedural_shadow_budget() -> bool:
	var torso := _player.get_node_or_null("Rig/Hips/Torso") as MeshInstance3D
	var strap := _player.get_node_or_null("Rig/Hips/MaraMessengerStrap") as MeshInstance3D
	var eyelid := _player.get_node_or_null("Rig/Hips/Head/MaraBlinkLid") as MeshInstance3D
	if torso == null or strap == null or eyelid == null:
		_fail("playable Mara shadow-budget nodes are missing")
		return false
	if torso.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("main playable Mara body shadow was disabled")
		return false
	if strap.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("playable Mara cosmetic strap still casts shadows")
		return false
	if eyelid.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("playable Mara blink eyelid still casts shadows")
		return false
	return true


func _check_procedural_cosmetic_lod() -> bool:
	var body := _player.get_node_or_null("Rig/Body")
	var torso := _player.get_node_or_null("Rig/Hips/Torso") as MeshInstance3D
	var strap := _player.get_node_or_null("Rig/Hips/MaraMessengerStrap") as MeshInstance3D
	if body == null or torso == null or strap == null:
		_fail("playable Mara cosmetic LOD nodes are missing")
		return false
	if not strap.visible:
		_fail("playable Mara close cosmetic detail was hidden")
		return false
	_camera.look_at_from_position(Vector3(0.0, 1.12, 32.0), Vector3(0.0, 0.98, 0.0), Vector3.UP)
	_camera.make_current()
	body.call("_process", 0.016)
	if not torso.visible:
		_fail("playable Mara main body was hidden by cosmetic LOD")
		return false
	if strap.visible:
		_fail("playable Mara far cosmetic detail stayed visible")
		return false
	_camera.look_at_from_position(Vector3(0.0, 1.12, 4.2), Vector3(0.0, 0.98, 0.0), Vector3.UP)
	_camera.make_current()
	body.call("_process", 0.016)
	if not strap.visible:
		_fail("playable Mara close cosmetic detail was not restored")
		return false
	return true
