extends RefCounted
## Unit tests for CameraPath — the spline math under cinematic capture.
## A dolly that overshoots waypoints or changes speed mid-shot reads as
## amateur footage, so endpoints, monotonicity, and constant speed all pin.


func _line() -> PackedVector3Array:
	return PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(20, 0, 0)])


func test_curve_passes_through_endpoints() -> bool:
	var pts := _line()
	var start := CameraPath.sample(pts, 0.0)
	var finish := CameraPath.sample(pts, 1.0)
	return start.is_equal_approx(pts[0]) and finish.is_equal_approx(pts[2])


func test_curve_passes_through_interior_waypoint() -> bool:
	var pts := PackedVector3Array([Vector3.ZERO, Vector3(5, 3, 0), Vector3(10, 0, 0)])
	return CameraPath.sample(pts, 0.5).is_equal_approx(pts[1])


func test_single_point_path_is_constant() -> bool:
	var pts := PackedVector3Array([Vector3(1, 2, 3)])
	return CameraPath.sample(pts, 0.7) == Vector3(1, 2, 3)


func test_empty_path_returns_origin() -> bool:
	return CameraPath.sample(PackedVector3Array(), 0.5) == Vector3.ZERO


func test_t_clamps_outside_range() -> bool:
	var pts := _line()
	var below := CameraPath.sample(pts, -1.0)
	var above := CameraPath.sample(pts, 2.0)
	return below.is_equal_approx(pts[0]) and above.is_equal_approx(pts[2])


func test_arc_table_is_monotonic() -> bool:
	var table := CameraPath.arc_table(_line())
	for i in range(1, table.size()):
		if table[i] < table[i - 1]:
			return false
	return true


func test_arc_length_matches_straight_line() -> bool:
	var table := CameraPath.arc_table(_line())
	return absf(table[table.size() - 1] - 20.0) < 0.1


func test_constant_speed_on_uneven_waypoints() -> bool:
	# Waypoints bunch up at the start; arc-length lookup must still move the
	# camera equal distances for equal distance requests.
	var pts := PackedVector3Array(
		[Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(30, 0, 0)]
	)
	var table := CameraPath.arc_table(pts)
	var total: float = table[table.size() - 1]
	var prev := CameraPath.sample(pts, CameraPath.t_at_distance(table, 0.0))
	var max_step := 0.0
	var min_step := INF
	for i in range(1, 11):
		var cur := CameraPath.sample(pts, CameraPath.t_at_distance(table, total * i / 10.0))
		var step := prev.distance_to(cur)
		max_step = maxf(max_step, step)
		min_step = minf(min_step, step)
		prev = cur
	return max_step / min_step < 1.25


func test_t_at_distance_endpoints() -> bool:
	var table := CameraPath.arc_table(_line())
	var total: float = table[table.size() - 1]
	var at_zero := CameraPath.t_at_distance(table, 0.0)
	var at_end := CameraPath.t_at_distance(table, total)
	return at_zero == 0.0 and absf(at_end - 1.0) < 0.001


func test_ease_is_smooth_and_bounded() -> bool:
	var ok_bounds := CameraPath.ease_in_out(0.0) == 0.0 and CameraPath.ease_in_out(1.0) == 1.0
	var ok_mid := absf(CameraPath.ease_in_out(0.5) - 0.5) < 0.001
	var ok_clamp := CameraPath.ease_in_out(-5.0) == 0.0 and CameraPath.ease_in_out(5.0) == 1.0
	return ok_bounds and ok_mid and ok_clamp
