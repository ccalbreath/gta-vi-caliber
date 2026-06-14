extends RefCounted
## Unit tests for StreetLight.sample_along — even kerb-side spacing along roads.


func test_even_spacing_on_straight_path() -> bool:
	var path := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var pts := StreetLight.sample_along(path, 25.0, 2.0)
	# First lamp half a span in (12.5), then every 25 m: 12.5, 37.5, 62.5, 87.5.
	return pts.size() == 4 and absf(pts[0].x - 12.5) < 0.01


func test_offset_pushes_to_the_kerb() -> bool:
	var path := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var pts := StreetLight.sample_along(path, 25.0, 2.0)
	# Travelling +X, the left kerb is +Z(=y here): every point sits at y = 2.
	return absf(pts[0].y - 2.0) < 0.01


func test_short_path_is_empty() -> bool:
	return StreetLight.sample_along(PackedVector2Array([Vector2(0, 0)]), 25.0, 2.0).is_empty()


func test_nonpositive_spacing_is_empty() -> bool:
	var path := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	return StreetLight.sample_along(path, 0.0, 2.0).is_empty()


func test_spacing_carries_across_a_corner() -> bool:
	# L-shaped path, total length 100, spacing 20 → 5 evenly spaced lamps.
	var path := PackedVector2Array([Vector2(0, 0), Vector2(50, 0), Vector2(50, 50)])
	return StreetLight.sample_along(path, 20.0, 0.0).size() == 5
