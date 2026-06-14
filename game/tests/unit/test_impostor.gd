extends RefCounted
## Smoke test for the native Impostor GDExtension (engine/src/worldcore/).
## The octahedral + LOD math is exhaustively covered in C++
## (engine/tests/test_worldcore.cpp); this proves the class crosses into
## GDScript. Skips when the native module isn't built, like test_worldcore.gd.


func test_impostor_lod_and_atlas() -> bool:
	if not ClassDB.class_exists("Impostor"):
		print("Impostor native module absent — skipping")
		return true

	var imp: Object = ClassDB.instantiate("Impostor")
	imp.set("grid_size", 8)
	imp.set("fov_y_degrees", 60.0)
	imp.set("viewport_height", 1080.0)
	imp.set("switch_threshold_px", 32.0)

	# Straight-up view maps to the atlas center cell.
	if imp.call("atlas_cell_for_view", Vector3(0.0, 1.0, 0.0)) != Vector2i(4, 4):
		return false

	# On-screen size shrinks with distance.
	var near_px: float = imp.call("projected_radius_px", 10.0, 50.0)
	var far_px: float = imp.call("projected_radius_px", 10.0, 500.0)
	if not (near_px > far_px and far_px > 0.0):
		return false

	# Close object stays a mesh; far one swaps to the impostor billboard.
	return not imp.call("should_impostor", 10.0, 50.0) and imp.call("should_impostor", 10.0, 500.0)
