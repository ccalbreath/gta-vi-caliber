extends RefCounted
## Smoke test for the native CrowdSteering GDExtension (engine/src/worldcore/).
## The boids math is exhaustively covered in C++
## (engine/tests/test_worldcore.cpp); this proves the class crosses into
## GDScript. Skips when the native module isn't built, like test_worldcore.gd.


func test_crowd_steering_separates_and_clamps() -> bool:
	if not ClassDB.class_exists("CrowdSteering"):
		print("CrowdSteering native module absent — skipping")
		return true

	var cs: Object = ClassDB.instantiate("CrowdSteering")
	cs.set("separation_weight", 1.5)
	cs.set("alignment_weight", 1.0)
	cs.set("cohesion_weight", 1.0)
	cs.set("neighbor_radius", 4.0)
	cs.set("max_force", 8.0)

	# One neighbour just to the +x: the steering force should push -x (away) and
	# never exceed max_force.
	var positions := PackedVector2Array([Vector2(1.0, 0.0)])
	var velocities := PackedVector2Array([Vector2(0.0, 0.0)])
	var force: Vector2 = cs.call(
		"steer", Vector2(0.0, 0.0), Vector2(0.0, 0.0), positions, velocities
	)
	if force.x >= 0.0:
		return false
	if force.length() > 8.0 + 0.001:
		return false

	# No neighbours -> zero force.
	var empty := PackedVector2Array()
	var idle: Vector2 = cs.call("steer", Vector2(0.0, 0.0), Vector2(0.0, 0.0), empty, empty)
	if idle.length() >= 0.001:
		return false

	# arrive() heads toward a goal to the +x.
	cs.set("max_speed", 6.0)
	var to_goal: Vector2 = cs.call(
		"arrive", Vector2(0.0, 0.0), Vector2(0.0, 0.0), Vector2(50.0, 0.0), 5.0
	)
	if to_goal.x <= 0.0:
		return false

	# avoid() pushes away from an obstacle to the +x that the agent is inside.
	var obs := PackedVector2Array([Vector2(2.0, 0.0)])
	var radii := PackedFloat32Array([3.0])
	var push: Vector2 = cs.call("avoid", Vector2(0.0, 0.0), obs, radii, 1.0)
	return push.x < 0.0
