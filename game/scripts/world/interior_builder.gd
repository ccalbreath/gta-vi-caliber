class_name InteriorBuilder
extends RefCounted
## Generates a simple walk-in interior shell from a building footprint: a floor,
## inward-facing walls, and a ceiling. Paired with Enterable (which picks the
## buildings and door points), this gives the player a room to enter. Pure
## geometry like CityBuilder, so it unit-tests headless
## (tests/unit/test_interior_builder.gd).

const UP := Vector3.UP
const DOWN := Vector3.DOWN


## Build a room shell for `footprint` (local metres) from floor_y up to
## floor_y + ceiling_height. Walls face inward; floor faces up, ceiling down.
## Returns {} for a degenerate footprint.
static func room(
	footprint: PackedVector2Array, ceiling_height: float, floor_y: float = 0.0
) -> Dictionary:
	var ring := CityBuilder.clean_ring(footprint)
	if ring.size() < 3:
		return {}
	# Counter-clockwise so the inward normal is well-defined.
	if CityBuilder.signed_area(ring) < 0.0:
		ring.reverse()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var top := floor_y + ceiling_height
	var n := ring.size()

	# Inward-facing walls.
	for i in n:
		var a := ring[i]
		var b := ring[(i + 1) % n]
		var dir := b - a
		if dir.length() < 0.001:
			continue
		# Inward normal = opposite of the outward (-90°-rotated) edge normal.
		var inward := Vector3(-dir.y, 0.0, dir.x).normalized()
		var base := vertices.size()
		vertices.append(Vector3(a.x, floor_y, a.y))
		vertices.append(Vector3(b.x, floor_y, b.y))
		vertices.append(Vector3(b.x, top, b.y))
		vertices.append(Vector3(a.x, top, a.y))
		for _k in 4:
			normals.append(inward)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])

	var tri := Geometry2D.triangulate_polygon(ring)
	if not tri.is_empty():
		# Floor (faces up).
		var floor_base := vertices.size()
		for p in ring:
			vertices.append(Vector3(p.x, floor_y, p.y))
			normals.append(UP)
		var t := 0
		while t + 2 < tri.size():
			indices.append_array(
				[floor_base + tri[t], floor_base + tri[t + 1], floor_base + tri[t + 2]]
			)
			t += 3
		# Ceiling (faces down).
		var ceil_base := vertices.size()
		for p in ring:
			vertices.append(Vector3(p.x, top, p.y))
			normals.append(DOWN)
		t = 0
		while t + 2 < tri.size():
			indices.append_array(
				[ceil_base + tri[t], ceil_base + tri[t + 2], ceil_base + tri[t + 1]]
			)
			t += 3

	return {"vertices": vertices, "normals": normals, "indices": indices}
