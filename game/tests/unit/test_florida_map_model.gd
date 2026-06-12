extends RefCounted
## Unit tests for the original peninsula-scale map model.


func test_outline_is_closed_on_request() -> bool:
	var outline := FloridaMapModel.closed_outline()
	return outline.size() == FloridaMapModel.OUTLINE.size() + 1 and outline[0] == outline[-1]


func test_city_nodes_scale_positions() -> bool:
	var scale := 3.0
	var cities := FloridaMapModel.city_nodes(scale)
	var base: Vector2 = FloridaMapModel.CITY_NODES[0]["position"]
	var scaled: Vector2 = cities[0]["position"]
	return scaled == base * scale


func test_roads_have_multiple_points() -> bool:
	for path in FloridaMapModel.road_paths():
		if path.size() < 2:
			return false
	return true


func test_bridge_paths_are_road_segments() -> bool:
	for path in FloridaMapModel.bridge_paths():
		if path.size() != 2:
			return false
		if path[0].distance_to(path[1]) <= 1.0:
			return false
	return true


func test_route_samples_have_position_and_direction() -> bool:
	var samples := FloridaMapModel.route_samples(2.0, 300.0)
	if samples.is_empty():
		return false
	for sample in samples:
		if not sample.has("position") or not sample.has("direction"):
			return false
		var dir: Vector2 = sample["direction"]
		if absf(dir.length() - 1.0) > 0.001:
			return false
	return true


func test_poi_markers_cover_core_map_features() -> bool:
	var markers := FloridaMapModel.poi_markers()
	var counts := {"city": 0, "landmark": 0, "marina": 0, "route": 0}
	for marker in markers:
		var kind: String = marker["kind"]
		if counts.has(kind):
			counts[kind] += 1
	return (
		counts["city"] == FloridaMapModel.CITY_NODES.size()
		and counts["landmark"] == FloridaMapModel.LANDMARKS.size()
		and counts["marina"] == FloridaMapModel.MARINAS.size()
		and counts["route"] > 0
	)


func test_map_center_and_extent_scale() -> bool:
	var extent_a := FloridaMapModel.map_extent(1.0)
	var extent_b := FloridaMapModel.map_extent(2.0)
	var center_a := FloridaMapModel.map_center(1.0)
	var center_b := FloridaMapModel.map_center(2.0)
	return extent_b == extent_a * 2.0 and center_b.is_equal_approx(center_a * 2.0)


func test_key_islands_scale_size_and_position() -> bool:
	var scale := 2.5
	var islands := FloridaMapModel.key_islands(scale)
	var base_position: Vector2 = FloridaMapModel.KEY_ISLANDS[0]["position"]
	var base_size: Vector2 = FloridaMapModel.KEY_ISLANDS[0]["size"]
	return (
		islands[0]["position"] == base_position * scale and islands[0]["size"] == base_size * scale
	)


func test_marinas_have_positive_slip_counts() -> bool:
	for marina in FloridaMapModel.marinas():
		if int(marina["slips"]) <= 0:
			return false
	return true


func test_landmarks_scale_positions() -> bool:
	var scale := 1.75
	var landmarks := FloridaMapModel.landmarks(scale)
	var base: Vector2 = FloridaMapModel.LANDMARKS[0]["position"]
	return (
		landmarks.size() == FloridaMapModel.LANDMARKS.size()
		and landmarks[0]["position"] == base * scale
	)


func test_landmarks_have_known_kinds() -> bool:
	var allowed := {"lighthouse": true, "wheel": true, "launch": true, "arch": true}
	for landmark in FloridaMapModel.landmarks():
		if not allowed.has(landmark["kind"]):
			return false
	return true


func test_wetlands_are_inside_outline() -> bool:
	var scale := 2.0
	for p in FloridaMapModel.wetland_points(40, scale):
		if not FloridaMapModel.contains_point(p, scale):
			return false
	return true


func test_bounds_expand_with_scale() -> bool:
	var a := FloridaMapModel.bounds(1.0)
	var b := FloridaMapModel.bounds(2.0)
	return b.size.x > a.size.x and b.size.y > a.size.y
