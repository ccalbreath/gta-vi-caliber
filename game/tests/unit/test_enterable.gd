extends RefCounted
## Unit tests for Enterable — which buildings can be entered, and where the door is.


func test_named_building_is_enterable() -> bool:
	return Enterable.is_enterable({"name": "U.S. Bank Tower", "kind": "yes"})


func test_public_type_is_enterable() -> bool:
	return Enterable.is_enterable({"name": "", "kind": "retail"})


func test_plain_house_is_not_enterable() -> bool:
	return not Enterable.is_enterable({"name": "", "kind": "house"})


func test_door_is_midpoint_of_longest_edge() -> bool:
	# A 10x2 rectangle: longest edges are the length-10 sides. Door on one of them.
	var fp := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 2), Vector2(0, 2)])
	var door := Enterable.door_point(fp)
	return absf(door.x - 5.0) < 0.001 and (absf(door.y) < 0.001 or absf(door.y - 2.0) < 0.001)


func test_pick_caps_count() -> bool:
	var buildings: Array = []
	for i in 10:
		buildings.append({"name": "Shop %d" % i, "kind": "retail"})
	return Enterable.pick(buildings, 3).size() == 3


func test_pick_skips_non_enterable() -> bool:
	var buildings: Array = [
		{"name": "", "kind": "house"},
		{"name": "Cafe", "kind": "retail"},
		{"name": "", "kind": "yes"},
	]
	return Enterable.pick(buildings, 10).size() == 1
