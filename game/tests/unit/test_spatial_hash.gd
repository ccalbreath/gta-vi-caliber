extends RefCounted
## Smoke test for the native SpatialHash GDExtension (engine/src/worldcore/).
## The grid + radius math is exhaustively covered in C++
## (engine/tests/test_worldcore.cpp); this proves the class crosses into
## GDScript. Skips when the native module isn't built, like test_worldcore.gd.


func test_spatial_hash_inserts_and_queries() -> bool:
	if not ClassDB.class_exists("SpatialHash"):
		print("SpatialHash native module absent — skipping")
		return true

	var h: Object = ClassDB.instantiate("SpatialHash")
	h.set("cell_size", 8.0)
	h.call("insert", 1, Vector2(0.0, 0.0))
	h.call("insert", 2, Vector2(3.0, 0.0))  # within 5
	h.call("insert", 3, Vector2(100.0, 100.0))  # far
	h.call("insert", 4, Vector2(8.5, 0.0))  # different cell, but >5 from origin

	if int(h.call("size")) != 4:
		return false

	var near: PackedInt32Array = h.call("query_radius", Vector2(0.0, 0.0), 5.0)
	# ids 1 and 2 are within 5; 3 (far) and 4 (8.5) are not.
	if not (1 in near and 2 in near):
		return false
	if 3 in near or 4 in near:
		return false

	# Cross-cell neighbour: query around id 4 finds it.
	var around4: PackedInt32Array = h.call("query_radius", Vector2(8.5, 0.0), 1.0)
	return 4 in around4
