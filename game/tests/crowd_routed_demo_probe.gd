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
	# Now actually assert "separated": a flow-ONLY crowd stacks onto the goal
	# point (spread -> ~0); separation must keep a real spread (Codex review).
	var spread := _spread(demo)
	# Routed to the goal, never clipped a wall, and stayed separated.
	if final >= initial * 0.6 or not path_clean or spread < 2.0:
		print(
			(
				"  FAIL: routed crowd weak (goal-dist %.1f -> %.1f, spread %.1f, clean=%s)"
				% [initial, final, spread, str(path_clean)]
			)
		)
		return false

	print(
		(
			"  OK: %d agents routed (mean dist %.1f -> %.1f), 0 wall hits, spread %.1f"
			% [demo.agent_count, initial, final, spread]
		)
	)
	return true


func _mean_goal_dist(demo: CrowdRoutedDemo, goal: Vector2) -> float:
	var sum := 0.0
	for i in demo.agent_count:
		sum += demo.positions[i].distance_to(goal)
	return sum / float(demo.agent_count)


## Mean distance of the agents from their centroid — proves the crowd stayed
## spread (separation working), not collapsed onto a single point.
func _spread(demo: CrowdRoutedDemo) -> float:
	var centroid := Vector2.ZERO
	for i in demo.agent_count:
		centroid += demo.positions[i]
	centroid /= float(demo.agent_count)
	var sum := 0.0
	for i in demo.agent_count:
		sum += demo.positions[i].distance_to(centroid)
	return sum / float(demo.agent_count)
