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


func test_palm_trunk_is_tall_and_slim() -> bool:
	# Palm trunk reaches its height and stays slim (radius < 0.4 m across).
	var box := _aabb(TreeMesh.palm_trunk(9.0, 0.22, 0.14))
	return absf(box.size.y - 9.0) < 0.1 and box.size.x < 0.8 and box.position.y > -0.01


func test_frond_droops_below_its_base() -> bool:
	# A frond blade curves downward, so its lowest point is well below the base.
	var box := _aabb(TreeMesh.frond(3.0, 0.17, 1.7))
	return box.position.y < -0.5


func test_palm_crown_fans_out_at_top() -> bool:
	# Radial fronds give a wide spread and many verts, sitting up at the trunk top.
	var crown := TreeMesh.palm_crown(11, 3.0, 9.0)
	var box := _aabb(crown)
	var verts: int = (crown["vertices"] as PackedVector3Array).size()
	return verts > 100 and box.size.x > 3.0 and box.position.y > 6.0


func test_palm_normals_are_unit_length() -> bool:
	for n in TreeMesh.palm_crown()["normals"] as PackedVector3Array:
		if absf(n.length() - 1.0) > 0.001:
			return false
	return true


func test_palm_indices_in_range() -> bool:
	var geo := TreeMesh.palm_crown()
	var n: int = (geo["vertices"] as PackedVector3Array).size()
	for i in geo["indices"] as PackedInt32Array:
		if i < 0 or i >= n:
			return false
	return true


func test_palm_meshes_build_surfaces() -> bool:
	var trunk := TreeMesh.to_mesh(TreeMesh.palm_trunk())
	var crown := TreeMesh.to_mesh(TreeMesh.palm_crown())
	return (
		trunk != null
		and trunk.get_surface_count() == 1
		and crown != null
		and crown.get_surface_count() == 1
	)
