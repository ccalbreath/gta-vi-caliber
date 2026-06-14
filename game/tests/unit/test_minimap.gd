extends RefCounted
## Unit tests for Minimap pure helpers.


func test_segment_fully_inside_unchanged() -> bool:
	var r := Minimap.clip_segment_circle(Vector2(-5, 0), Vector2(5, 0), 10.0)
	return (
		r.size() == 2
		and r[0].is_equal_approx(Vector2(-5, 0))
		and r[1].is_equal_approx(Vector2(5, 0))
	)


func test_segment_crossing_clips_to_radius() -> bool:
	# Horizontal line from outside-left to centre, radius 10 → enters at x=-10.
	var r := Minimap.clip_segment_circle(Vector2(-20, 0), Vector2(0, 0), 10.0)
	return r.size() == 2 and absf(r[0].x - (-10.0)) < 0.0001 and r[1].is_equal_approx(Vector2(0, 0))


func test_segment_through_circle_clips_both_ends() -> bool:
	var r := Minimap.clip_segment_circle(Vector2(-20, 0), Vector2(20, 0), 10.0)
	return r.size() == 2 and absf(r[0].x + 10.0) < 0.0001 and absf(r[1].x - 10.0) < 0.0001


func test_segment_missing_circle_returns_empty() -> bool:
	var r := Minimap.clip_segment_circle(Vector2(-20, 50), Vector2(20, 50), 10.0)
	return r.is_empty()


func test_degenerate_point_outside_empty() -> bool:
	var r := Minimap.clip_segment_circle(Vector2(50, 50), Vector2(50, 50), 10.0)
	return r.is_empty()


func test_star_points_has_ten_vertices() -> bool:
	return WantedStars.star_points(Vector2.ZERO, 9.0).size() == 10


func test_poi_colors_cover_florida_marker_kinds() -> bool:
	for kind in ["city", "landmark", "marina", "route"]:
		if not Minimap.POI_COLORS.has(kind):
			return false
	return true


func test_poi_colors_keep_life_sandbox_kinds() -> bool:
	for kind in ["office", "diner", "bar", "gym", "home", "park", "restroom", "street"]:
		if not Minimap.POI_COLORS.has(kind):
			return false
	return true


func test_route_to_array_accepts_navgrid_packed_route() -> bool:
	var packed := PackedVector3Array([Vector3(0, 4, 0), Vector3(8, 4, 0)])
	var route := Minimap.route_to_array(packed)
	return (
		route.size() == 2
		and (route[0] as Vector3).is_equal_approx(Vector3(0, 4, 0))
		and (route[1] as Vector3).is_equal_approx(Vector3(8, 4, 0))
	)


func test_waypoint_route_links_player_to_waypoint_on_ground_plane() -> bool:
	var route := Minimap.waypoint_route(Vector3(2, 9, 3), Vector3(10, 4, 3), true)
	return (
		route.size() == 2
		and (route[0] as Vector3).is_equal_approx(Vector3(2, 0, 3))
		and (route[1] as Vector3).is_equal_approx(Vector3(10, 0, 3))
	)


func test_waypoint_route_empty_without_active_waypoint() -> bool:
	return Minimap.waypoint_route(Vector3.ZERO, Vector3(10, 0, 0), false).is_empty()


func test_waypoint_route_hides_after_arrival() -> bool:
	return Minimap.waypoint_route(Vector3(9.4, 0, 0), Vector3(10, 0, 0), true, 1.0).is_empty()


func test_route_points_snap_to_remaining_polyline() -> bool:
	var route := [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, -10)]
	var points := Minimap.route_points_from_position(Vector3(4, 0, 3), route, 1.0)
	return (
		points.size() == 4
		and (points[0] as Vector3).is_equal_approx(Vector3(4, 0, 3))
		and (points[1] as Vector3).is_equal_approx(Vector3(4, 0, 0))
		and (points[2] as Vector3).is_equal_approx(Vector3(10, 0, 0))
		and (points[3] as Vector3).is_equal_approx(Vector3(10, 0, -10))
	)


func test_route_points_skip_passed_leg() -> bool:
	var route := [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, -10)]
	var points := Minimap.route_points_from_position(Vector3(10, 0, -5), route, 1.0)
	return (
		points.size() == 2
		and (points[0] as Vector3).is_equal_approx(Vector3(10, 0, -5))
		and (points[1] as Vector3).is_equal_approx(Vector3(10, 0, -10))
	)


func test_route_points_empty_after_arrival() -> bool:
	var route := [Vector3(0, 0, 0), Vector3(10, 0, 0)]
	return Minimap.route_points_from_position(Vector3(9.5, 0, 0), route, 1.0).is_empty()
