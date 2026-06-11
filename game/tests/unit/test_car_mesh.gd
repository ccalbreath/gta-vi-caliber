extends RefCounted
## Unit tests for CarMesh procedural car-body geometry: correct overall bounds,
## smooth outward normals, and a buildable surface.


func _aabb(geo: Dictionary) -> AABB:
	var verts: PackedVector3Array = geo["vertices"]
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	return AABB(lo, hi - lo)


func test_body_matches_requested_length_and_width() -> bool:
	var box := _aabb(CarMesh.body(4.2, 1.9))
	return absf(box.size.z - 4.2) < 0.05 and box.size.x <= 1.9 + 0.01


func test_body_roof_reaches_cabin_height() -> bool:
	# The greenhouse should peak near the roofline control max (~1.34 m).
	var box := _aabb(CarMesh.body())
	return box.position.y + box.size.y > 1.25


func test_normals_are_unit_length() -> bool:
	var geo := CarMesh.body(4.2, 1.9, 10, 12)
	for n in geo["normals"] as PackedVector3Array:
		if absf(n.length() - 1.0) > 0.001:
			return false
	return true


func test_side_normals_point_outward() -> bool:
	# A vertex out on the +X flank should shade away from the centreline, proving
	# the side winding produces outward (not inward) faces.
	var geo := CarMesh.body(4.2, 1.9, 16, 16)
	var verts: PackedVector3Array = geo["vertices"]
	var normals: PackedVector3Array = geo["normals"]
	var worst := 1.0
	for i in verts.size():
		if verts[i].x > 0.8:  # clearly on the right flank
			worst = minf(worst, normals[i].x)
	# At least the flank as a whole faces +X.
	return worst > -0.2


func test_indices_in_range() -> bool:
	var geo := CarMesh.body(4.2, 1.9, 12, 12)
	var n: int = (geo["vertices"] as PackedVector3Array).size()
	for i in geo["indices"] as PackedInt32Array:
		if i < 0 or i >= n:
			return false
	return true


func test_to_mesh_builds_surface() -> bool:
	var mesh := CarMesh.to_mesh(CarMesh.body())
	return mesh != null and mesh.get_surface_count() == 1


func test_to_mesh_empty_is_null() -> bool:
	return CarMesh.to_mesh({}) == null
