extends SceneTree
## Capacity benchmark for the native crowd sim: how many agents can be stepped
## (SpatialHash rebuild + per-agent neighbour gather + CrowdSteering) within a
## single 60 FPS frame budget (16 ms)? Answers the GTA-density question — so the
## agents are packed to a *realistic crowd density* (~TARGET_NEIGHBOURS within
## the steering radius, not a sparse field), and the probe reports the measured
## density so the number is honest (Codex review). Skips when natives are absent.
##
## Run: godot --headless --path game --script res://tests/crowd_capacity_probe.gd

const RADIUS := 4.0
const TARGET_NEIGHBOURS := 12.0  # dense crowd: each agent sees ~12 others
const SIZES := [500, 1000, 2000, 4000]
const BUDGET_MS := 16.0  # 60 FPS frame budget
const REPS := 8


func _initialize() -> void:
	var ok := _run()
	print("crowd_capacity_probe: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	if not (ClassDB.class_exists("SpatialHash") and ClassDB.class_exists("CrowdSteering")):
		print("  native crowd modules absent — skipping (OK)")
		return true

	var hash: Object = ClassDB.instantiate("SpatialHash")
	hash.set("cell_size", RADIUS)
	var steer: Object = ClassDB.instantiate("CrowdSteering")
	steer.set("neighbor_radius", RADIUS)

	var capacity := 0
	for n in SIZES:
		var r := _measure(n, hash, steer)
		var ms: float = r["ms"]
		var under := ms < BUDGET_MS
		if under:
			capacity = n
		print(
			(
				"  N=%d (~%.1f neighbours/agent): %.2f ms/step %s"
				% [n, r["neighbours"], ms, "(<16ms)" if under else "(over budget)"]
			)
		)

	print("  capacity ~%d dense-crowd agents within the 16 ms (60 FPS) budget" % capacity)
	# GTA-density bar: >=1000 agents at realistic density, per frame, at 60 FPS.
	return capacity >= 1000


## One full crowd step over `n` agents at realistic density. Returns the average
## milliseconds per step and the measured neighbours-per-agent (so the density
## the number was taken at is explicit, not assumed).
func _measure(n: int, hash: Object, steer: Object) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Pick the field so the expected count within RADIUS hits TARGET_NEIGHBOURS:
	# density d = K/(pi*R^2); area = n/d; span(half-width) = 0.5*sqrt(area).
	var area := float(n) * PI * RADIUS * RADIUS / TARGET_NEIGHBOURS
	var span := 0.5 * sqrt(area)
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	pos.resize(n)
	vel.resize(n)
	for i in n:
		pos[i] = Vector2(rng.randf_range(-span, span), rng.randf_range(-span, span))
		vel[i] = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))

	# Warmup + density census (untimed): also primes allocations/JIT paths.
	hash.call("clear")
	for i in n:
		hash.call("insert", i, pos[i])
	var total_neighbours := 0
	for i in n:
		var ids: PackedInt32Array = hash.call("query_radius", pos[i], RADIUS)
		total_neighbours += ids.size() - 1  # exclude self
	var avg_neighbours := float(total_neighbours) / float(n)

	var t0 := Time.get_ticks_usec()
	for _r in REPS:
		hash.call("clear")
		for i in n:
			hash.call("insert", i, pos[i])
		for i in n:
			var ids: PackedInt32Array = hash.call("query_radius", pos[i], RADIUS)
			var npos := PackedVector2Array()
			var nvel := PackedVector2Array()
			for id in ids:
				if id == i:
					continue
				npos.append(pos[id])
				nvel.append(vel[id])
			steer.call("steer", pos[i], vel[i], npos, nvel)
	var ms := float(Time.get_ticks_usec() - t0) / float(REPS) / 1000.0

	return {"ms": ms, "neighbours": avg_neighbours}
