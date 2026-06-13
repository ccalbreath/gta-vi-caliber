extends SceneTree
func _init():
	var root3d = Node3D.new()
	get_root().add_child(root3d)
	# Build a simple up-facing roof quad with CURRENT (down) winding and FIXED (up) winding,
	# put each in its own trimesh body, raycast downward, report hits.
	for label in ["CURRENT_down_winding", "FIXED_up_winding"]:
		var v = PackedVector3Array([Vector3(0,10,0),Vector3(10,10,0),Vector3(10,10,10),Vector3(0,10,10)])
		var idx
		if label == "CURRENT_down_winding":
			# triangulate gave [3,0,1,1,2,3], roof appended verbatim -> gn = -Y
			idx = PackedInt32Array([3,0,1, 1,2,3])
		else:
			idx = PackedInt32Array([3,1,0, 1,3,2])
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX]=v
		arr[Mesh.ARRAY_INDEX]=idx
		var am = ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var shape = am.create_trimesh_shape()
		var body = StaticBody3D.new()
		var cs = CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		root3d.add_child(body)
		# raycast straight down through point (5,?,5)
		var space = root3d.get_world_3d().direct_space_state
		var q = PhysicsRayQueryParameters3D.create(Vector3(5,50,5), Vector3(5,-50,5))
		var hit = space.intersect_ray(q)
		print(label, " downward ray hit=", not hit.is_empty(), " ", hit.get("position", "MISS"))
		root3d.remove_child(body)
		body.free()
	quit()
