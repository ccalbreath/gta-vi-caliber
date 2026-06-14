extends RefCounted
## Unit tests for InteriorBuilder — the walk-in room shell.


static func _square() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)])


func test_room_vertex_and_index_counts() -> bool:
	# 4 walls × 4 verts + floor 4 + ceiling 4 = 24 verts.
	# 4 walls × 6 + floor 6 + ceiling 6 = 36 indices.
	var geo := InteriorBuilder.room(_square(), 4.0)
	return (
		(geo["vertices"] as PackedVector3Array).size() == 24
		and (geo["indices"] as PackedInt32Array).size() == 36
	)


func test_room_spans_floor_to_ceiling() -> bool:
	var geo := InteriorBuilder.room(_square(), 4.0, 2.0)
	var min_y := INF
	var max_y := -INF
	for v in geo["vertices"] as PackedVector3Array:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	return absf(min_y - 2.0) < 0.001 and absf(max_y - 6.0) < 0.001


func test_floor_faces_up_ceiling_faces_down() -> bool:
	var geo := InteriorBuilder.room(_square(), 4.0)
	var has_up := false
	var has_down := false
	for nrm in geo["normals"] as PackedVector3Array:
		if nrm.is_equal_approx(Vector3.UP):
			has_up = true
		elif nrm.is_equal_approx(Vector3.DOWN):
			has_down = true
	return has_up and has_down


func test_wall_normals_point_inward() -> bool:
	# For this CCW square centred at (4,4), every wall normal should point toward
	# the centre — i.e. dot(normal, centre - wall_point) > 0.
	var geo := InteriorBuilder.room(_square(), 4.0)
	var verts: PackedVector3Array = geo["vertices"]
	var normals: PackedVector3Array = geo["normals"]
	var centre := Vector3(4, 2, 4)
	for i in 16:  # first 16 verts are walls
		var nrm := normals[i]
		if absf(nrm.y) > 0.001:
			continue
		var to_centre := centre - verts[i]
		to_centre.y = 0
		if nrm.dot(to_centre.normalized()) <= 0.0:
			return false
	return true


func test_degenerate_footprint_is_empty() -> bool:
	return InteriorBuilder.room(PackedVector2Array([Vector2(0, 0), Vector2(1, 0)]), 4.0).is_empty()


func test_builds_into_mesh() -> bool:
	var geo := InteriorBuilder.room(_square(), 3.0)
	var mesh := CityBuilder.arrays_to_mesh(geo)
	return mesh != null and mesh.get_surface_count() == 1
