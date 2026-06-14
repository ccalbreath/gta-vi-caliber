extends RefCounted
## Smoke test for the native TrafficModel GDExtension (engine/src/worldcore/).
## The IDM math is exhaustively covered in C++ (engine/tests/test_worldcore.cpp);
## this proves the class crosses into GDScript. Skips when the native module
## isn't built, like test_worldcore.gd.


func test_traffic_model_follows_and_brakes() -> bool:
	if not ClassDB.class_exists("TrafficModel"):
		print("TrafficModel native module absent — skipping")
		return true

	var t: Object = ClassDB.instantiate("TrafficModel")
	t.set("desired_speed", 30.0)
	t.set("max_accel", 1.5)
	t.set("comfort_decel", 2.0)
	t.set("min_gap", 2.0)
	t.set("time_headway", 1.5)

	# Clear road, below desired speed -> accelerate.
	if float(t.call("acceleration", 5.0, 1000.0, 30.0)) <= 0.0:
		return false
	# Small gap to a stopped leader -> brake.
	if float(t.call("acceleration", 20.0, 5.0, 0.0)) >= 0.0:
		return false
	# At desired speed on a clear road -> roughly coast.
	return absf(t.call("acceleration", 30.0, 1000.0, 30.0)) < 0.1
