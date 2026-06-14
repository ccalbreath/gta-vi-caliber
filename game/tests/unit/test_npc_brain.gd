extends RefCounted
## Unit tests for NpcBrain (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).


func test_wander_target_within_radius() -> bool:
	for i in range(0, 11):
		for j in range(0, 11):
			var p := NpcBrain.wander_target(Vector3(5, 0, 5), 8.0, float(i) / 10.0, float(j) / 10.0)
			if NpcBrain.planar_distance(p, Vector3(5, 0, 5)) > 8.001:
				return false
	return true


func test_wander_target_ignores_y() -> bool:
	var p := NpcBrain.wander_target(Vector3(0, 3, 0), 5.0, 0.5, 0.5)
	return is_equal_approx(p.y, 3.0)


func test_planar_distance_ignores_height() -> bool:
	return is_equal_approx(NpcBrain.planar_distance(Vector3(0, 10, 0), Vector3(3, -2, 4)), 5.0)


func test_arrived_true_within_tolerance() -> bool:
	return NpcBrain.arrived(Vector3(0, 0, 0), Vector3(0.5, 0, 0), 1.0)


func test_arrived_false_when_far() -> bool:
	return not NpcBrain.arrived(Vector3(0, 0, 0), Vector3(5, 0, 0), 1.0)


func test_planar_dir_is_unit() -> bool:
	var d := NpcBrain.planar_dir(Vector3(0, 0, 0), Vector3(3, 9, 4))
	return is_equal_approx(d.length(), 1.0) and is_equal_approx(d.y, 0.0)


func test_planar_dir_zero_when_coincident() -> bool:
	return NpcBrain.planar_dir(Vector3(1, 0, 1), Vector3(1, 5, 1)) == Vector3.ZERO


func test_flee_dir_points_away_from_threat() -> bool:
	# Threat at -x, self at origin → flee toward +x.
	var d := NpcBrain.flee_dir(Vector3(0, 0, 0), Vector3(-2, 0, 0))
	return d.is_equal_approx(Vector3(1, 0, 0))


func test_pursue_dir_points_toward_target() -> bool:
	# Target at +x, self at origin → pursue toward +x (opposite of flee).
	var d := NpcBrain.pursue_dir(Vector3(0, 0, 0), Vector3(5, 0, 0))
	return d.is_equal_approx(Vector3(1, 0, 0))


func test_pursue_and_flee_are_opposite() -> bool:
	var self_pos := Vector3(2, 0, 3)
	var other := Vector3(-4, 0, 9)
	return NpcBrain.pursue_dir(self_pos, other).is_equal_approx(-NpcBrain.flee_dir(self_pos, other))


func test_enters_flee_when_threat_close_and_active() -> bool:
	return NpcBrain.next_state(NpcBrain.State.WANDER, true, 4.0, 8.0, 14.0) == NpcBrain.State.FLEE


func test_stays_wander_when_no_threat() -> bool:
	return (
		NpcBrain.next_state(NpcBrain.State.WANDER, false, 2.0, 8.0, 14.0) == NpcBrain.State.WANDER
	)


func test_ignores_distant_threat() -> bool:
	return (
		NpcBrain.next_state(NpcBrain.State.WANDER, true, 20.0, 8.0, 14.0) == NpcBrain.State.WANDER
	)


func test_flee_hysteresis_keeps_running_inside_calm_radius() -> bool:
	# Already fleeing, threat still active and within calm radius → keep fleeing
	# even though it is now beyond the (tighter) flee radius.
	return NpcBrain.next_state(NpcBrain.State.FLEE, true, 10.0, 8.0, 14.0) == NpcBrain.State.FLEE


func test_flee_ends_beyond_calm_radius() -> bool:
	return NpcBrain.next_state(NpcBrain.State.FLEE, true, 16.0, 8.0, 14.0) == NpcBrain.State.WANDER


func test_flee_ends_when_threat_gone() -> bool:
	return NpcBrain.next_state(NpcBrain.State.FLEE, false, 3.0, 8.0, 14.0) == NpcBrain.State.WANDER


func test_speed_for_states() -> bool:
	var idle := NpcBrain.speed_for(NpcBrain.State.IDLE, 3.0, 7.0)
	var wander := NpcBrain.speed_for(NpcBrain.State.WANDER, 3.0, 7.0)
	var flee := NpcBrain.speed_for(NpcBrain.State.FLEE, 3.0, 7.0)
	return (
		is_equal_approx(idle, 0.0) and is_equal_approx(wander, 3.0) and is_equal_approx(flee, 7.0)
	)
