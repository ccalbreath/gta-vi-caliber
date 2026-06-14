class_name StreetLight
extends RefCounted
## Pure placement math for street furniture: evenly spaced points along a road
## polyline, offset to the kerb side.
##
## Static and scene-free so it unit-tests headless (tests/unit/test_street_light.gd).
## DistrictLoader feeds it projected road paths and drops an emissive lamp node at
## each returned position, so the night city reads as a field of streetlights.


## Points spaced `spacing` metres along the polyline, pushed `side_offset` metres
## to the polyline's left (the kerb). Distance carries across segments so spacing
## stays even around corners. Returns XZ positions (y added by the caller).
static func sample_along(
	path: PackedVector2Array, spacing: float, side_offset: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.size() < 2 or spacing <= 0.0:
		return out
	var carry: float = spacing * 0.5  # first lamp half a span in, not on the corner
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var seg: Vector2 = b - a
		var seg_len: float = seg.length()
		if seg_len < 1e-4:
			continue
		var dir: Vector2 = seg / seg_len
		var kerb: Vector2 = Vector2(-dir.y, dir.x) * side_offset
		var pos: float = carry
		while pos < seg_len:
			out.append(a + dir * pos + kerb)
			pos += spacing
		carry = pos - seg_len  # leftover distance into the next segment
	return out
