extends SceneTree
## Headless end-to-end probe for the native crowd stack: loads
## crowd_native_demo.tscn, runs the SpatialHash + CrowdSteering simulation for a
## few seconds of frames, and asserts the crowd actually simulates — agents stay
## finite, in-bounds, and keep moving (flocking) rather than freezing or
## exploding. Skips cleanly when the native module isn't built.
##
## Run: godot --headless --path game --script res://tests/crowd_native_probe.gd


func _initialize() -> void:
	var ok := _run()
	print("crowd_native_probe: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	if not (ClassDB.class_exists("SpatialHash") and ClassDB.class_exists("CrowdSteering")):
		print("  native worldcore modules absent — skipping (OK)")
		return true

	var packed := load("res://scenes/world/crowd_native_demo.tscn")
	if packed == null:
		print("  could not load crowd_native_demo.tscn")
		return false
	var demo: CrowdNativeDemo = packed.instantiate()
	demo.agent_count = 150
	demo.half_extent = 50.0
	demo._ready()  # explicit + deterministic (don't depend on tree _ready timing)

	# The top guard proved the classes exist, so the demo MUST activate them now.
	# A skip here would mask a real native-wiring failure (Codex review).
	if not demo.native_active():
		print("  FAIL: native classes exist but the demo did not activate them")
		return false

	for _f in 180:  # ~3 s at 60 Hz
		demo.step(1.0 / 60.0)

	var sum_speed := 0.0
	var sum_goal_dist := 0.0
	var goal: Vector2 = demo.current_goal()
	var valid := true
	for i in demo.agent_count:
		var p: Vector2 = demo.positions[i]
		if not (is_finite(p.x) and is_finite(p.y)):
			print("  FAIL: non-finite agent position at %d" % i)
			valid = false
			break
		if absf(p.x) > demo.half_extent + 1.0 or absf(p.y) > demo.half_extent + 1.0:
			print("  FAIL: agent %d left the field (%.1f, %.1f)" % [i, p.x, p.y])
			valid = false
			break
		sum_speed += demo.velocities[i].length()
		sum_goal_dist += p.distance_to(goal)

	if not valid:
		return false

	var avg_speed := sum_speed / float(demo.agent_count)
	var avg_goal_dist := sum_goal_dist / float(demo.agent_count)
	# Crowd must be moving (not frozen) AND gathering toward the goal: a scattered
	# field averages ~0.5*field from any point; a navigating crowd is well under
	# half_extent. One combined gate keeps the return count within lint limits.
	if avg_speed < 0.1 or avg_goal_dist > demo.half_extent:
		print(
			"  FAIL: crowd not navigating (speed %.2f, goal-dist %.1f)" % [avg_speed, avg_goal_dist]
		)
		return false

	print(
		(
			"  OK: %d agents, avg speed %.2f m/s, avg goal-dist %.1f, finite + in-bounds + navigating"
			% [demo.agent_count, avg_speed, avg_goal_dist]
		)
	)
	return true
