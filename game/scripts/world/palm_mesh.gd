class_name PalmMesh
extends RefCounted
## Pure procedural palm-tree geometry: a curved tapering trunk lofted along a
## parabolic spine, plus a crown of drooping frond blades fanned around the tip.
##
## Static and scene-free so it unit-tests headless (tests/unit/test_palm_mesh.gd).
## BeachProps builds a few trunk/crown variants once and scatters them along the
## Venice Beach sand line for the shoreline postcard foreground. Trunk base sits
## at y=0; the crown is authored around the origin and lifted onto the trunk tip
## (see `tip()`) by the placer. Geometry dicts are TreeMesh-compatible, so
## `TreeMesh.to_mesh()` packs them.

const TRUNK_RINGS := 8
const TRUNK_SEGMENTS := 8
const FROND_SEGMENTS := 5


## Curved tapering trunk: ring centres follow x = bend * t^2 so the palm leans
## over progressively, the classic wind-swept beach silhouette.
static func trunk(
	height: float = 9.0, bend: float = 1.4, base_radius: float = 0.3, top_radius: float = 0.17
) -> Dictionary:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in TRUNK_RINGS + 1:
		var t: float = float(i) / float(TRUNK_RINGS)
		var centre := Vector3(bend * t * t, height * t, 0.0)
		var radius: float = lerpf(base_radius, top_radius, pow(t, 0.7))
		for k in TRUNK_SEGMENTS:
			var a: float = float(k) / float(TRUNK_SEGMENTS) * TAU
			verts.append(centre + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	for i in TRUNK_RINGS:
		var s0: int = i * TRUNK_SEGMENTS
		var s1: int = (i + 1) * TRUNK_SEGMENTS
		for k in TRUNK_SEGMENTS:
			var k2: int = (k + 1) % TRUNK_SEGMENTS
			indices.append_array([s0 + k, s1 + k, s0 + k2, s0 + k2, s1 + k, s1 + k2])
	_cap(verts, indices, 0, TRUNK_SEGMENTS, Vector3.ZERO, true)
	_cap(verts, indices, TRUNK_RINGS * TRUNK_SEGMENTS, TRUNK_SEGMENTS, tip(height, bend), false)
	return {"vertices": verts, "normals": _smooth_normals(verts, indices), "indices": indices}


## Where the trunk tip ends up — the crown attach point for the placer.
static func tip(height: float = 9.0, bend: float = 1.4) -> Vector3:
	return Vector3(bend, height, 0.0)


## One frond blade in local space: a tapered strip pointing +X from the origin
## that arcs up then droops. Rendered with culling disabled (double-sided).
static func frond(
	length: float = 3.4, width: float = 0.62, rise: float = 0.6, droop: float = 1.6
) -> Dictionary:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for j in FROND_SEGMENTS + 1:
		var s: float = float(j) / float(FROND_SEGMENTS)
		var spine := Vector3(length * s, rise * s - droop * s * s, 0.0)
		var half: float = width * 0.5 * sin(s * PI)
		verts.append(spine + Vector3(0.0, 0.0, -half))
		verts.append(spine + Vector3(0.0, 0.0, half))
	for j in FROND_SEGMENTS:
		var a: int = j * 2
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	return {"vertices": verts, "normals": _smooth_normals(verts, indices), "indices": indices}


## A full crown: `count` fronds fanned around the y-axis with seeded per-frond
## yaw jitter, downward pitch, and length variety. Deterministic for a seed, so
## a handful of crown variants can be shared across the whole palm row.
static func crown(
	count: int = 7, length: float = 3.4, width: float = 0.62, seed_value: int = 0
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var geo := {
		"vertices": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"indices": PackedInt32Array(),
	}
	for i in count:
		var blade := frond(length * rng.randf_range(0.85, 1.15), width)
		var yaw: float = TAU * float(i) / float(count) + rng.randf_range(-0.22, 0.22)
		var pitch: float = rng.randf_range(-0.05, 0.5)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -pitch)
		var verts: PackedVector3Array = blade["vertices"]
		for v in verts.size():
			verts[v] = basis * verts[v]
		blade["vertices"] = verts
		_merge(geo, blade)
	geo["normals"] = _smooth_normals(geo["vertices"], geo["indices"])
	return geo


static func _cap(
	verts: PackedVector3Array,
	indices: PackedInt32Array,
	start: int,
	segments: int,
	centre: Vector3,
	low: bool
) -> void:
	var c: int = verts.size()
	verts.append(centre)
	for k in segments:
		var k2: int = (k + 1) % segments
		if low:
			indices.append_array([c, start + k2, start + k])
		else:
			indices.append_array([c, start + k, start + k2])


static func _merge(dst: Dictionary, src: Dictionary) -> void:
	var verts: PackedVector3Array = dst["vertices"]
	var indices: PackedInt32Array = dst["indices"]
	var base: int = verts.size()
	verts.append_array(src["vertices"])
	for i in src["indices"] as PackedInt32Array:
		indices.append(base + i)
	dst["vertices"] = verts
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
