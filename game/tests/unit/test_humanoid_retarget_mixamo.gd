class_name TestHumanoidRetargetMixamo
extends GdUnitTestSuite
## Verifies HumanoidRetarget also bridges Mixamo-named skeletons (mixamorig:*),
## so converted Meshy/Mixamo NPC visuals retarget the universal clips instead of
## standing frozen in a T-pose. The Tripo path must keep working unchanged.


func test_mixamo_core_chain_maps_to_source() -> void:
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:Hips"))).is_equal("pelvis")
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:Spine1"))).is_equal("spine_02")
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:Head"))).is_equal("Head")


func test_mixamo_limbs_and_toes_map() -> void:
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:LeftArm"))).is_equal("upperarm_l")
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:RightLeg"))).is_equal("calf_r")
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:LeftToeBase"))).is_equal("ball_l")


func test_underscore_prefix_also_works() -> void:
	# Godot sanitises the colon to an underscore on import.
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig_LeftUpLeg"))).is_equal("thigh_l")


func test_tripo_names_unchanged() -> void:
	assert_str(String(HumanoidRetarget.source_name(&"Hips"))).is_equal("pelvis")
	assert_str(String(HumanoidRetarget.source_name(&"LeftUpperArm"))).is_equal("upperarm_l")


func test_unknown_stays_unmapped() -> void:
	assert_str(String(HumanoidRetarget.source_name(&"Tail"))).is_equal("")
	assert_str(String(HumanoidRetarget.source_name(&"mixamorig:Tail"))).is_equal("")
