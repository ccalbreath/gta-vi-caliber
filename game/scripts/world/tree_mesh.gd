class_name TreeMesh
extends RefCounted
## Pure procedural tree geometry: a tapered bark trunk and a leafy canopy built
## from overlapping lofted blobs.
##
## Static and scene-free so it unit-tests headless (tests/unit/test_tree_mesh.gd).
## DistrictLoader generates the trunk and canopy meshes once (bark + leaf
## materials) and scatters them as street trees along the roads, so the city has
## greenery instead of bare tarmac. Trunk base sits at y=0; canopy is authored in
## its own local space and lifted onto the trunk by the placer.


## Tapered bark trunk, base at y=0 up to `height`, narrowing toward the crown.
static func trunk(
	height: float = 3.6, base_radius: float = 0.17, top_radius: float = 0.1
) -> Dictionary:
	var rings: Array = []
	var count: int = 6
	for i in count + 1:
		var t: float = float(i) / float(count)
		rings.append(
			Vector3(
				t * height, lerpf(base_radius, top_radius, t), lerpf(base_radius, top_radius, t)
			)
		)
	return _loft(rings, 10)


## Leafy canopy: three overlapping squashed-sphere blobs merged into one mesh for
## an irregular, fuller silhouette than a single lollipop ball.
static func canopy(radius: float = 1.5) -> Dictionary:
	var geo := _blob(radius, Vector3.ZERO)
	_merge(geo, _blob(radius * 0.72, Vector3(radius * 0.62, radius * 0.34, radius * 0.2)))
	_merge(geo, _blob(radius * 0.66, Vector3(-radius * 0.5, radius * 0.22, -radius * 0.4)))
	return geo


## A squashed-sphere foliage blob centred at `offset`.
static func _blob(radius: float, offset: Vector3) -> Dictionary:
	var rings: Array = []
	var count: int = 8
	for i in count + 1:
		var s: float = float(i) / float(count)
		var y: float = lerpf(-radius * 0.85, radius * 0.95, s)
		var r: float = radius * sin(s * PI)
		rings.append(Vector3(y, r, r))
	var geo := _loft(rings, 12)
	if offset != Vector3.ZERO:
		var verts: PackedVector3Array = geo["vertices"]
		for i in verts.size():
			verts[i] += offset
		geo["vertices"] = verts
	return geo


static func _loft(rings: Array, segments: int) -> Dictionary:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var ring_start := PackedInt32Array()
	for ring in rings:
		ring_start.append(verts.size())
		for k in segments:
			var a: float = float(k) / float(segments) * TAU
			verts.append(Vector3(cos(a) * ring.y, ring.x, sin(a) * ring.z))
	for i in range(rings.size() - 1):
		var s0: int = ring_start[i]
		var s1: int = ring_start[i + 1]
		for k in segments:
			var k2: int = (k + 1) % segments
			indices.append_array([s0 + k, s1 + k, s0 + k2, s0 + k2, s1 + k, s1 + k2])
	_cap(verts, indices, ring_start[0], segments, rings[0].x, true)
	_cap(verts, indices, ring_start[rings.size() - 1], segments, rings[rings.size() - 1].x, false)
	return {"vertices": verts, "normals": _smooth_normals(verts, indices), "indices": indices}


static func _cap(
	verts: PackedVector3Array,
	indices: PackedInt32Array,
	start: int,
	segments: int,
	y: float,
	low: bool
) -> void:
	var c: int = verts.size()
	verts.append(Vector3(0.0, y, 0.0))
	for k in segments:
		var k2: int = (k + 1) % segments
		if low:
			indices.append_array([c, start + k2, start + k])
		else:
			indices.append_array([c, start + k, start + k2])


static func _merge(dst: Dictionary, src: Dictionary) -> void:
	var verts: PackedVector3Array = dst["vertices"]
	var normals: PackedVector3Array = dst["normals"]
	var indices: PackedInt32Array = dst["indices"]
	var base: int = verts.size()
	verts.append_array(src["vertices"])
	normals.append_array(src["normals"])
	for i in src["indices"] as PackedInt32Array:
		indices.append(base + i)
	dst["vertices"] = verts
	dst["normals"] = normals
	dst["indices"] = indices


static func _smooth_normals(
	verts: PackedVector3Array, indices: PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var i: int = 0
	while i + 2 < indices.size():
		var ia: int = indices[i]
		var ib: int = indices[i + 1]
		var ic: int = indices[i + 2]
		var face: Vector3 = (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
		normals[ia] += face
		normals[ib] += face
		normals[ic] += face
		i += 3
	for n in normals.size():
		var v: Vector3 = normals[n]
		normals[n] = v.normalized() if v.length_squared() > 1e-12 else Vector3.UP
	return normals


## Pack a geometry dict into an ArrayMesh surface. Empty → null.
static func to_mesh(geo: Dictionary) -> ArrayMesh:
	if geo.is_empty() or (geo["vertices"] as PackedVector3Array).is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geo["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = geo["normals"]
	arrays[Mesh.ARRAY_INDEX] = geo["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
