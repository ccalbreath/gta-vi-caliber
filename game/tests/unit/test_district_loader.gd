extends RefCounted
## Focused tests for district scene assembly helpers.


func test_facade_panels_generate_dark_and_lit_windows() -> bool:
	var ring := PackedVector2Array([Vector2(0, 0), Vector2(24, 0), Vector2(24, 18), Vector2(0, 18)])
	var dark: Array[Transform3D] = []
	var lit: Array[Transform3D] = []
	DistrictFacadePanels.collect_transforms(ring, 32.0, 37, dark, lit)
	return dark.size() > 20 and lit.size() > 6


func test_facade_panel_generation_respects_caps() -> bool:
	var ring := PackedVector2Array(
		[Vector2(0, 0), Vector2(120, 0), Vector2(120, 80), Vector2(0, 80)]
	)
	var dark: Array[Transform3D] = []
	var lit: Array[Transform3D] = []
	DistrictFacadePanels.collect_transforms(ring, 160.0, 91, dark, lit)
	return dark.size() <= 2600 and lit.size() <= 900
