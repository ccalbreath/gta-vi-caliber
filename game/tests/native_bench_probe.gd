extends SceneTree
## Profiling probe that justifies the native worldcore ports (the project's
## "C++ only when profiled" rule): it times the native SpatialHash neighbour
## query against the equivalent naive GDScript O(n^2) search over the same data,
## checks they return the SAME neighbour counts (fair comparison), and asserts
## the native path is faster. Skips cleanly when the native module is absent.
##
## Run: godot --headless --path game --script res://tests/native_bench_probe.gd

const N := 600
const RADIUS := 5.0
const ITERS := 15


func _initialize() -> void:
	var ok := _run()
	print("native_bench_probe: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run() -> bool:
	if not ClassDB.class_exists("SpatialHash"):
		print("  native SpatialHash absent — skipping (OK)")
		return true

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pos := PackedVector2Array()
	pos.resize(N)
	for i in N:
		pos[i] = Vector2(rng.randf_range(-100.0, 100.0), rng.randf_range(-100.0, 100.0))

	var hash: Object = ClassDB.instantiate("SpatialHash")
	hash.set("cell_size", RADIUS)

	# Native: rebuild the grid and query every agent, ITERS times.
	var native_count := 0
	var t0 := Time.get_ticks_usec()
	for _it in ITERS:
		hash.call("clear")
		for i in N:
			hash.call("insert", i, pos[i])
		for i in N:
			var ids: PackedInt32Array = hash.call("query_radius", pos[i], RADIUS)
			native_count += ids.size()
	var native_us := Time.get_ticks_usec() - t0

	# GDScript: the naive all-pairs equivalent over the same data.
	var gd_count := 0
	var r2 := RADIUS * RADIUS
	t0 = Time.get_ticks_usec()
	for _it in ITERS:
		for i in N:
			var pi := pos[i]
			for j in N:
				if pi.distance_squared_to(pos[j]) <= r2:
					gd_count += 1
	var gd_us := Time.get_ticks_usec() - t0

	var speedup := float(gd_us) / float(maxi(native_us, 1))
	print(
		(
			"  n=%d iters=%d | native %d us | gdscript %d us | speedup %.1fx"
			% [N, ITERS, native_us, gd_us, speedup]
		)
	)

	# Fairness 1: same total neighbour COUNT across all queries (cheap aggregate).
	if native_count != gd_count:
		print("  FAIL: counts differ — native %d vs gdscript %d" % [native_count, gd_count])
		return false
	# Fairness 2 (untimed, rigorous): the native query returns the exact same
	# neighbour SET as the GDScript scan for a sample agent — not just the same
	# count (Codex review: matching totals alone could mask wrong ids).
	if not _sets_match(hash, pos, 0):
		print("  FAIL: native neighbour SET differs from GDScript for the sample agent")
		return false
	# The whole point of the port: native must beat the naive GDScript search.
	if native_us >= gd_us:
		print("  FAIL: native not faster (%d us vs %d us)" % [native_us, gd_us])
		return false

	print("  OK: native neighbour query is %.1fx faster than naive GDScript" % speedup)
	return true


## True when the native query for `sample` returns exactly the GDScript set.
func _sets_match(hash: Object, pos: PackedVector2Array, sample: int) -> bool:
	var native_set := {}
	for id in hash.call("query_radius", pos[sample], RADIUS):
		native_set[id] = true
	var gd_set := {}
	var ps := pos[sample]
	var r2 := RADIUS * RADIUS
	for j in pos.size():
		if ps.distance_squared_to(pos[j]) <= r2:
			gd_set[j] = true
	if native_set.size() != gd_set.size():
		return false
	for k in native_set:
		if not gd_set.has(k):
			return false
	return true
