class_name PathSmoother
extends RefCounted
## String-pulling for NavGrid routes: A* returns one waypoint per cell, so paths
## zig-zag along the grid. This greedily drops any waypoint the car/ped can see
## past, leaving only the corners where the line of sight actually breaks — so
## agents drive and walk in straight runs instead of stair-stepping.
##
## Pure and deterministic (tests/unit/test_path_smoother.gd): line of sight is a
## fine-step sample of the segment against the grid's blocked cells, so a
## simplified leg never cuts through a building.


## True if the straight segment a→b (cell coords) crosses no blocked cell. Sampled
## at quarter-cell steps, which is dense enough that a 1-cell obstacle can't slip
## between samples.
static func line_of_sight(grid: NavGrid, a: Vector2i, b: Vector2i) -> bool:
	var wa := grid.cell_to_world(a.x, a.y)
	var wb := grid.cell_to_world(b.x, b.y)
	var dist := wa.distance_to(wb)
	var steps := maxi(int(ceil(dist / (grid.cell_size * 0.25))), 1)
	for s in range(0, steps + 1):
		var t := float(s) / float(steps)
		var p := wa.lerp(wb, t)
		var cell := grid.world_to_cell(p)
		if grid.is_blocked(cell.x, cell.y):
			return false
	return true


## Greedily simplify a cell path: from each kept point, jump to the farthest later
## point still in line of sight. Keeps endpoints; collapses straight runs.
static func simplify_cells(grid: NavGrid, cells: Array) -> Array:
	if cells.size() <= 2:
		return cells.duplicate()
	var out: Array = [cells[0]]
	var i := 0
	var n := cells.size()
	while i < n - 1:
		var j := n - 1
		while j > i + 1 and not line_of_sight(grid, cells[i], cells[j]):
			j -= 1
		out.append(cells[j])
		i = j
	return out


## Convenience: smooth a world-space route (e.g. straight from NavGrid.find_path).
## Returns world waypoints; preserves each point's y.
static func simplify_world(grid: NavGrid, waypoints: PackedVector3Array) -> PackedVector3Array:
	if waypoints.size() <= 2:
		return waypoints
	var cells: Array = []
	for w: Vector3 in waypoints:
		cells.append(grid.world_to_cell(w))
	var kept := simplify_cells(grid, cells)
	# cell_to_world uses the grid's origin y; carry the route's own height instead
	# (routes are planar, so the first waypoint's y stands in for the leg).
	var y := waypoints[0].y
	var out := PackedVector3Array()
	for c: Vector2i in kept:
		var w := grid.cell_to_world(c.x, c.y)
		out.append(Vector3(w.x, y, w.z))
	return out
