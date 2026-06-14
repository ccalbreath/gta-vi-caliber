extends RefCounted
## Unit tests for PathSmoother (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func _grid(cols: int = 20, rows: int = 20, cs: float = 1.0) -> NavGrid:
	return NavGrid.new(cols, rows, cs, Vector3.ZERO)


func test_los_clear_on_open_grid() -> bool:
	var g := _grid()
	return PathSmoother.line_of_sight(g, Vector2i(0, 0), Vector2i(10, 5))


func test_los_blocked_by_wall() -> bool:
	var g := _grid()
	for r in range(0, 20):
		g.set_blocked(5, r, true)  # full vertical wall at col 5
	return not PathSmoother.line_of_sight(g, Vector2i(2, 3), Vector2i(9, 3))


func test_simplify_straight_run_to_two() -> bool:
	var g := _grid()
	var cells: Array = []
	for c in range(0, 10):
		cells.append(Vector2i(c, 0))
	var out := PathSmoother.simplify_cells(g, cells)
	return out.size() == 2 and out[0] == Vector2i(0, 0) and out[1] == Vector2i(9, 0)


func test_simplify_keeps_endpoints() -> bool:
	var g := _grid()
	var cells := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
	var out := PathSmoother.simplify_cells(g, cells)
	return out[0] == Vector2i(0, 0) and out[out.size() - 1] == Vector2i(3, 3)


func test_simplify_short_path_unchanged() -> bool:
	var g := _grid()
	var cells := [Vector2i(0, 0), Vector2i(4, 0)]
	return PathSmoother.simplify_cells(g, cells).size() == 2


func test_simplify_keeps_corner_around_obstacle() -> bool:
	var g := _grid()
	# Block a square so a path from (1,1) to (1,8)→(8,8) must bend at a corner.
	for r in range(0, 7):
		g.set_blocked(4, r, true)
	# A stair-stepped path hugging the wall and turning the corner at the gap.
	var cells := [
		Vector2i(1, 1),
		Vector2i(2, 3),
		Vector2i(3, 5),
		Vector2i(3, 8),
		Vector2i(5, 8),
		Vector2i(8, 8),
	]
	var out := PathSmoother.simplify_cells(g, cells)
	# Must keep more than the two endpoints (there's a real corner), and every
	# kept leg must have clear line of sight (never shortcut through the wall).
	if out.size() < 3:
		return false
	for i in range(1, out.size()):
		if not PathSmoother.line_of_sight(g, out[i - 1], out[i]):
			return false
	return true


func test_simplify_world_preserves_y() -> bool:
	var g := _grid()
	var wp := PackedVector3Array(
		[Vector3(0.5, 3.0, 0.5), Vector3(1.5, 3.0, 0.5), Vector3(9.5, 3.0, 0.5)]
	)
	var out := PathSmoother.simplify_world(g, wp)
	return out.size() >= 2 and is_equal_approx(out[0].y, 3.0)
