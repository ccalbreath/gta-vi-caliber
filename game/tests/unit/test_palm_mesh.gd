extends RefCounted
## Unit tests for PalmMesh: curved trunk reaches its height and leans by the
## bend, fronds span and droop, crowns fan in all directions, and the geometry
## packs into a renderable surface.


func _aabb(geo: Dictionary) -> AABB:
	var verts: PackedVector3Array = geo["vertices"]
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	return AABB(lo, hi - lo)


func test_trunk_reaches_its_height() -> bool:
	var box := _aabb(PalmMesh.trunk(9.0, 1.4, 0.3, 0.17))
	return absf(box.position.y + box.size.y - 9.0) < 0.01 and box.position.y > -0.01


func test_trunk_leans_by_the_bend() -> bool:
	# Top ring centre sits at x = bend, so max x must reach bend - top_radius.
	var box := _aabb(PalmMesh.trunk(9.0, 1.4, 0.3, 0.17))
	var max_x: float = box.position.x + box.size.x
	return max_x > 1.4 - 0.17 - 0.01 and max_x < 1.4 + 0.17 + 0.01


func test_tip_matches_trunk_top() -> bool:
	return PalmMesh.tip(9.0, 1.4).is_equal_approx(Vector3(1.4, 9.0, 0.0))


func test_frond_spans_its_length_and_droops() -> bool:
	var geo := PalmMesh.frond(3.4, 0.62, 0.6, 1.6)
	var box := _aabb(geo)
	var tip: Vector3 = (geo["vertices"] as PackedVector3Array)[-1]
	return absf(box.size.x - 3.4) < 0.01 and tip.y < -0.5


func test_crown_fans_all_directions() -> bool:
	# Seven fronds yawed around up must spread the crown in both x and z.
	var box := _aabb(PalmMesh.crown(7, 3.4, 0.62, 1))
	return box.size.x > 3.4 and box.size.z > 3.4


func test_crown_vert_count_scales_with_fronds() -> bool:
	var one: int = (PalmMesh.crown(1, 3.4, 0.62, 5)["vertices"] as PackedVector3Array).size()
	var seven: int = (PalmMesh.crown(7, 3.4, 0.62, 5)["vertices"] as PackedVector3Array).size()
	return seven == one * 7


func test_crown_is_deterministic_per_seed() -> bool:
	var a: PackedVector3Array = PalmMesh.crown(7, 3.4, 0.62, 9)["vertices"]
	var b: PackedVector3Array = PalmMesh.crown(7, 3.4, 0.62, 9)["vertices"]
	return a == b


func test_normals_are_unit_length() -> bool:
	for geo in [PalmMesh.trunk(), PalmMesh.crown()]:
		for n in geo["normals"] as PackedVector3Array:
			if absf(n.length() - 1.0) > 0.001:
				return false
	return true


func test_indices_in_range() -> bool:
	for geo in [PalmMesh.trunk(), PalmMesh.frond(), PalmMesh.crown()]:
		var n: int = (geo["vertices"] as PackedVector3Array).size()
		for i in geo["indices"] as PackedInt32Array:
			if i < 0 or i >= n:
				return false
	return true


func test_to_mesh_builds_surface() -> bool:
	var mesh := TreeMesh.to_mesh(PalmMesh.crown())
	return mesh != null and mesh.get_surface_count() == 1
