extends RefCounted
## Regression guard for the building-collision fix (commit eaa94af).
##
## extrude_prism's wall triangles must be wound so their geometric (winding)
## normal points OUTWARD, matching the shading normal. Trimesh collision
## (ConcavePolygonShape3D) keys off winding and ignores backfaces, so if the walls
## ever get wound inward again the whole city silently becomes non-solid
## (characters, cars, bullets pass through buildings) while still looking fine.
## This fails loudly the moment that regresses.


func _square() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])


# Every wall triangle (one that spans the base and the top, so it has verts at
# both y=0 and y=20) must have its winding normal agree with its outward shading
# normal. Roof caps are excluded — their triangulation winding is tested by the
# headless collision probe, not here.
func test_wall_winding_faces_outward() -> bool:
	var geo := CityBuilder.extrude_prism(_square(), 0.0, 20.0)
	var verts: PackedVector3Array = geo["vertices"]
	var norms: PackedVector3Array = geo["normals"]
	var idx: PackedInt32Array = geo["indices"]
	var walls_checked := 0
	var t := 0
	while t + 2 < idx.size():
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		var ys := [verts[i0].y, verts[i1].y, verts[i2].y]
		var spans_height: bool = ys.min() < 1.0 and ys.max() > 19.0
		if spans_height:
			walls_checked += 1
			var face := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
			if face.length_squared() < 1e-9:
				return false  # degenerate
			var shading := norms[i0] + norms[i1] + norms[i2]
			if face.dot(shading) <= 0.0:
				return false  # inward-wound wall → backfaced → non-solid city
		t += 3
	# A 4-wall box yields 8 wall triangles; make sure we actually exercised them.
	return walls_checked >= 4
