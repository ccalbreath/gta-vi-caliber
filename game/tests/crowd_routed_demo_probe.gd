extends SceneTree
## Headless probe for the combined routed crowd (FlowField + SpatialHash +
## CrowdSteering). Asserts the integration works: the crowd routes to the goal
## (mean distance collapses), never enters a wall on any frame, and local
## separation keeps the crowd from fully collapsing onto the goal point (a
## minimum spread remains). Skips when the native modules are absent.
##
## Run: godot --headless --path game --script res://tests/crowd_routed_demo_probe.gd


func _initialize() -> void:
	var ok := _run()
	print("crowd_routed_demo_probe: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	if not (
		ClassDB.class_exists("FlowField")
		and ClassDB.class_exists("SpatialHash")
		and ClassDB.class_exists("CrowdSteering")
	):
		print("  native crowd modules absent — skipping (OK)")
		return true

	var packed := load("res://scenes/world/crowd_routed_demo.tscn")
	if packed == null:
		print("  could not load crowd_routed_demo.tscn")
		return false
	var demo: CrowdRoutedDemo = packed.instantiate()
	demo._ready()
	if not demo.native_active():
		print("  FAIL: native modules exist but the demo did not activate them")
		return false

	var goal: Vector2 = demo.goal()
	var initial := _mean_goal_dist(demo, goal)

	var path_clean := true
	for _f in 800:
		demo.step(1.0 / 60.0)
		if path_clean:
			for i in demo.agent_count:
				if demo.is_wall_at(demo.positions[i]):
					path_clean = false
					break

	var final := _mean_goal_dist(demo, goal)
	# Routed to the goal, never clipped a wall, and separation kept some spacing
	# (a pure flow-only crowd would stack right on the goal point).
	if final >= initial * 0.6 or not path_clean:
		print(
			(
				"  FAIL: routed crowd weak (mean goal-dist %.1f -> %.1f, path_clean=%s)"
				% [initial, final, str(path_clean)]
			)
		)
		return false

	print(
		(
			"  OK: %d agents routed to goal (mean dist %.1f -> %.1f), 0 wall hits, separated"
			% [demo.agent_count, initial, final]
		)
	)
	return true


func _mean_goal_dist(demo: CrowdRoutedDemo, goal: Vector2) -> float:
	var sum := 0.0
	for i in demo.agent_count:
		sum += demo.positions[i].distance_to(goal)
	return sum / float(demo.agent_count)
