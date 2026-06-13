class_name HumanoidRetarget
extends RefCounted
## Bone-name bridge from the Tripo humanoid rig to the Quaternius animation rig.
##
## RetargetModifier3D matches bones by name. The imported target skeleton and
## its private skin bind names are renamed together, while the source rig keeps
## the names referenced by the existing animation tracks.

const TARGET_TO_SOURCE: Dictionary = {
	&"Hips": &"pelvis",
	&"Spine": &"spine_01",
	&"Chest": &"spine_02",
	&"UpperChest": &"spine_03",
	&"Neck": &"neck_01",
	&"Head": &"Head",
	&"LeftShoulder": &"clavicle_l",
	&"LeftUpperArm": &"upperarm_l",
	&"LeftLowerArm": &"lowerarm_l",
	&"LeftHand": &"hand_l",
	&"LeftThumbMetacarpal": &"thumb_01_l",
	&"LeftThumbProximal": &"thumb_02_l",
	&"LeftThumbDistal": &"thumb_03_l",
	&"LeftIndexProximal": &"index_01_l",
	&"LeftIndexIntermediate": &"index_02_l",
	&"LeftIndexDistal": &"index_03_l",
	&"LeftMiddleProximal": &"middle_01_l",
	&"LeftMiddleIntermediate": &"middle_02_l",
	&"LeftMiddleDistal": &"middle_03_l",
	&"LeftRingProximal": &"ring_01_l",
	&"LeftRingIntermediate": &"ring_02_l",
	&"LeftRingDistal": &"ring_03_l",
	&"LeftLittleProximal": &"pinky_01_l",
	&"LeftLittleIntermediate": &"pinky_02_l",
	&"LeftLittleDistal": &"pinky_03_l",
	&"RightShoulder": &"clavicle_r",
	&"RightUpperArm": &"upperarm_r",
	&"RightLowerArm": &"lowerarm_r",
	&"RightHand": &"hand_r",
	&"RightThumbMetacarpal": &"thumb_01_r",
	&"RightThumbProximal": &"thumb_02_r",
	&"RightThumbDistal": &"thumb_03_r",
	&"RightIndexProximal": &"index_01_r",
	&"RightIndexIntermediate": &"index_02_r",
	&"RightIndexDistal": &"index_03_r",
	&"RightMiddleProximal": &"middle_01_r",
	&"RightMiddleIntermediate": &"middle_02_r",
	&"RightMiddleDistal": &"middle_03_r",
	&"RightRingProximal": &"ring_01_r",
	&"RightRingIntermediate": &"ring_02_r",
	&"RightRingDistal": &"ring_03_r",
	&"RightLittleProximal": &"pinky_01_r",
	&"RightLittleIntermediate": &"pinky_02_r",
	&"RightLittleDistal": &"pinky_03_r",
	&"LeftUpperLeg": &"thigh_l",
	&"LeftLowerLeg": &"calf_l",
	&"LeftFoot": &"foot_l",
	&"LeftToes": &"ball_l",
	&"RightUpperLeg": &"thigh_r",
	&"RightLowerLeg": &"calf_r",
	&"RightFoot": &"foot_r",
	&"RightToes": &"ball_r",
}

# Mixamo names its bones differently from the canonical humanoid set above
# (its mesh comes out of Meshy then auto-rigged in Mixamo). Map each Mixamo bone
# to the canonical name so converted Mixamo visuals retarget like the Tripo ones.
const MIXAMO_TO_CANONICAL: Dictionary = {
	&"Hips": &"Hips",
	&"Spine": &"Spine",
	&"Spine1": &"Chest",
	&"Spine2": &"UpperChest",
	&"Neck": &"Neck",
	&"Head": &"Head",
	&"LeftShoulder": &"LeftShoulder",
	&"LeftArm": &"LeftUpperArm",
	&"LeftForeArm": &"LeftLowerArm",
	&"LeftHand": &"LeftHand",
	&"LeftHandThumb1": &"LeftThumbMetacarpal",
	&"LeftHandThumb2": &"LeftThumbProximal",
	&"LeftHandThumb3": &"LeftThumbDistal",
	&"LeftHandIndex1": &"LeftIndexProximal",
	&"LeftHandIndex2": &"LeftIndexIntermediate",
	&"LeftHandIndex3": &"LeftIndexDistal",
	&"LeftHandMiddle1": &"LeftMiddleProximal",
	&"LeftHandMiddle2": &"LeftMiddleIntermediate",
	&"LeftHandMiddle3": &"LeftMiddleDistal",
	&"LeftHandRing1": &"LeftRingProximal",
	&"LeftHandRing2": &"LeftRingIntermediate",
	&"LeftHandRing3": &"LeftRingDistal",
	&"LeftHandPinky1": &"LeftLittleProximal",
	&"LeftHandPinky2": &"LeftLittleIntermediate",
	&"LeftHandPinky3": &"LeftLittleDistal",
	&"RightShoulder": &"RightShoulder",
	&"RightArm": &"RightUpperArm",
	&"RightForeArm": &"RightLowerArm",
	&"RightHand": &"RightHand",
	&"RightHandThumb1": &"RightThumbMetacarpal",
	&"RightHandThumb2": &"RightThumbProximal",
	&"RightHandThumb3": &"RightThumbDistal",
	&"RightHandIndex1": &"RightIndexProximal",
	&"RightHandIndex2": &"RightIndexIntermediate",
	&"RightHandIndex3": &"RightIndexDistal",
	&"RightHandMiddle1": &"RightMiddleProximal",
	&"RightHandMiddle2": &"RightMiddleIntermediate",
	&"RightHandMiddle3": &"RightMiddleDistal",
	&"RightHandRing1": &"RightRingProximal",
	&"RightHandRing2": &"RightRingIntermediate",
	&"RightHandRing3": &"RightRingDistal",
	&"RightHandPinky1": &"RightLittleProximal",
	&"RightHandPinky2": &"RightLittleIntermediate",
	&"RightHandPinky3": &"RightLittleDistal",
	&"LeftUpLeg": &"LeftUpperLeg",
	&"LeftLeg": &"LeftLowerLeg",
	&"LeftFoot": &"LeftFoot",
	&"LeftToeBase": &"LeftToes",
	&"RightUpLeg": &"RightUpperLeg",
	&"RightLeg": &"RightLowerLeg",
	&"RightFoot": &"RightFoot",
	&"RightToeBase": &"RightToes",
}


## Strip a "mixamorig:" or "mixamorig_" prefix (Godot sanitises the colon to an
## underscore on import), leaving the bare Mixamo bone name.
static func _strip_mixamo(bone_name: StringName) -> StringName:
	var s := String(bone_name)
	for prefix in ["mixamorig:", "mixamorig_"]:
		if s.begins_with(prefix):
			return StringName(s.substr(prefix.length()))
	return bone_name


## The canonical humanoid name for a skeleton bone, whether it already uses the
## canonical naming (Tripo) or Mixamo naming. Empty if it is neither.
static func canonical(bone_name: StringName) -> StringName:
	if TARGET_TO_SOURCE.has(bone_name):
		return bone_name
	return MIXAMO_TO_CANONICAL.get(_strip_mixamo(bone_name), &"")


## Source-rig bone name for a target bone, accepting canonical or Mixamo naming.
## Empty when the bone is not part of the humanoid set.
static func source_name(bone_name: StringName) -> StringName:
	var canon := canonical(bone_name)
	if canon == &"":
		return &""
	return TARGET_TO_SOURCE.get(canon, &"")


static func source_bone_names() -> PackedStringArray:
	var names := PackedStringArray()
	for target_name: StringName in TARGET_TO_SOURCE:
		names.append(TARGET_TO_SOURCE[target_name])
	return names


static func rename_target_skeleton(skeleton: Skeleton3D) -> PackedStringArray:
	_rename_skin_binds(skeleton)
	var found := {}
	for bone_idx in skeleton.get_bone_count():
		var src := source_name(skeleton.get_bone_name(bone_idx))
		if src != &"":
			skeleton.set_bone_name(bone_idx, src)
			found[src] = true
	var missing := PackedStringArray()
	for target_name: StringName in TARGET_TO_SOURCE:
		if not found.has(TARGET_TO_SOURCE[target_name]):
			missing.append(target_name)
	return missing


static func _rename_skin_binds(skeleton: Skeleton3D) -> void:
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.skin == null:
			continue
		var renamed_skin := mesh_instance.skin.duplicate() as Skin
		for bind_idx in renamed_skin.get_bind_count():
			var mapped_name := source_name(renamed_skin.get_bind_name(bind_idx))
			if not mapped_name.is_empty():
				renamed_skin.set_bind_name(bind_idx, mapped_name)
		mesh_instance.skin = renamed_skin


static func build_profile() -> SkeletonProfile:
	var names := source_bone_names()
	var profile := SkeletonProfile.new()
	profile.bone_size = names.size()
	for bone_idx in names.size():
		profile.set_bone_name(bone_idx, names[bone_idx])
	return profile
