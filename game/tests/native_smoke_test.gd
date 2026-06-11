extends SceneTree
## Smoke test for the engine/ GDExtension modules. Run via:
##   godot --headless --path game --script res://tests/native_smoke_test.gd
##
## Unlike tests/smoke_test.gd this REQUIRES the native library: it only runs
## where the extension was just built (CI engine job, or locally after a
## build + manifest copy per engine/README.md). The regular game CI job runs
## without native modules on purpose — graceful degradation stays enforced.


func _initialize() -> void:
	if not ClassDB.class_exists("NativeBench"):
		push_error("native smoke: NativeBench not registered — extension failed to load")
		quit(1)
		return
	var bench: Variant = ClassDB.instantiate("NativeBench")
	var failures := 0
	if bench.ping() != "pong from C++":
		push_error("native smoke: ping() returned %s" % bench.ping())
		failures += 1
	if bench.sum_of_squares(10) != 285:
		push_error("native smoke: sum_of_squares(10) returned %d" % bench.sum_of_squares(10))
		failures += 1
	if failures == 0:
		print("native smoke: OK")
	quit(failures)
