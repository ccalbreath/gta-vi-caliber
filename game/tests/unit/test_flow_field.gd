extends RefCounted
## Smoke test for the native FlowField GDExtension (engine/src/worldcore/).
## The Dijkstra + flow math is exhaustively covered in C++
## (engine/tests/test_worldcore.cpp); this proves the class crosses into
## GDScript. Skips when the native module isn't built, like test_worldcore.gd.


func test_flow_field_builds_and_routes() -> bool:
	if not ClassDB.class_exists("FlowField"):
		print("FlowField native module absent — skipping")
		return true

	var ff: Object = ClassDB.instantiate("FlowField")
	ff.set("cell_size", 4.0)
	ff.set("origin", Vector2(0.0, 0.0))

	# 5x5 open grid (all passable), goal at the far corner cell (4,4) -> world ~(18,18).
	var costs := PackedFloat32Array()
	costs.resize(25)
	costs.fill(1.0)
	ff.call("build", 5, 5, costs, Vector2(18.0, 18.0))
	if not ff.call("is_built"):
		return false

	# From near the origin corner, the routing direction heads toward the goal
	# (+x, +z).
	var dir: Vector2 = ff.call("direction_at", Vector2(2.0, 2.0))
	if dir.x <= 0.0 or dir.y <= 0.0:
		return false

	# A position outside the grid returns zero (no routing info there).
	var outside: Vector2 = ff.call("direction_at", Vector2(-50.0, -50.0))
	return outside == Vector2.ZERO
