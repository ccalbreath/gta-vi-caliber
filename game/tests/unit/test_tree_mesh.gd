extends RefCounted
## Unit tests for TreeMesh: trunk height, a fuller (multi-blob) canopy, smooth
## normals, and a buildable surface.


func _aabb(geo: Dictionary) -> AABB:
	var verts: PackedVector3Array = geo["vertices"]
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	return AABB(lo, hi - lo)


func test_trunk_reaches_its_height() -> bool:
	var box := _aabb(TreeMesh.trunk(3.6, 0.17, 0.1))
	return absf(box.size.y - 3.6) < 0.05 and box.position.y > -0.01


func test_canopy_is_fuller_than_a_single_blob() -> bool:
	# Three merged blobs must give more verts than one, and a wide spread.
	var canopy := TreeMesh.canopy(1.5)
	var box := _aabb(canopy)
	return (canopy["vertices"] as PackedVector3Array).size() > 100 and box.size.x > 1.6


func test_normals_are_unit_length() -> bool:
	var geo := TreeMesh.canopy(1.5)
	for n in geo["normals"] as PackedVector3Array:
		if absf(n.length() - 1.0) > 0.001:
			return false
	return true


func test_indices_in_range() -> bool:
	var geo := TreeMesh.trunk()
	var n: int = (geo["vertices"] as PackedVector3Array).size()
	for i in geo["indices"] as PackedInt32Array:
		if i < 0 or i >= n:
			return false
	return true


func test_to_mesh_builds_surface() -> bool:
	var mesh := TreeMesh.to_mesh(TreeMesh.trunk())
	return mesh != null and mesh.get_surface_count() == 1


func test_to_mesh_empty_is_null() -> bool:
	return TreeMesh.to_mesh({}) == null
