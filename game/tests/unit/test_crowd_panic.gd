extends RefCounted
## Unit tests for CrowdPanic — the crowd-wave panic field (see tests/run_tests.gd
## for the runner contract: zero-arg test_* methods return true to pass).

# --- initial_fear ------------------------------------------------------------


func test_initial_fear_max_at_epicentre() -> bool:
	var f := CrowdPanic.initial_fear(Vector3.ZERO, Vector3.ZERO, 10.0)
	return is_equal_approx(f, 1.0)


func test_initial_fear_falls_with_distance() -> bool:
	# Halfway out of a 10m scare -> 0.5.
	var f := CrowdPanic.initial_fear(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, 10.0)
	return is_equal_approx(f, 0.5)


func test_initial_fear_zero_beyond_radius() -> bool:
	var f := CrowdPanic.initial_fear(Vector3(11.0, 0.0, 0.0), Vector3.ZERO, 10.0)
	return is_equal_approx(f, 0.0)


func test_initial_fear_ignores_height() -> bool:
	# A ped on a balcony 8m up but 5m out (XZ) reads the same as ground level.
	var f := CrowdPanic.initial_fear(Vector3(5.0, 8.0, 0.0), Vector3.ZERO, 10.0)
	return is_equal_approx(f, 0.5)


func test_initial_fear_zero_radius_guarded() -> bool:
	return is_equal_approx(CrowdPanic.initial_fear(Vector3.ZERO, Vector3.ZERO, 0.0), 0.0)


# --- propagated_fear ---------------------------------------------------------


func test_propagated_rises_with_nearer_neighbor() -> bool:
	var near := [{"pos": Vector3(1.0, 0.0, 0.0), "fear": 1.0}]
	var far := [{"pos": Vector3(4.0, 0.0, 0.0), "fear": 1.0}]
	var near_f := CrowdPanic.propagated_fear(Vector3.ZERO, near, 5.0, 1.0)
	var far_f := CrowdPanic.propagated_fear(Vector3.ZERO, far, 5.0, 1.0)
	return near_f > far_f and near_f > 0.0


func test_propagated_rises_with_more_afraid_neighbor() -> bool:
	var calm_ish := [{"pos": Vector3(1.0, 0.0, 0.0), "fear": 0.3}]
	var terrified := [{"pos": Vector3(1.0, 0.0, 0.0), "fear": 1.0}]
	var a := CrowdPanic.propagated_fear(Vector3.ZERO, calm_ish, 5.0, 1.0)
	var b := CrowdPanic.propagated_fear(Vector3.ZERO, terrified, 5.0, 1.0)
	return b > a and a > 0.0


func test_propagated_zero_from_calm_neighbors() -> bool:
	var calm := [{"pos": Vector3(1.0, 0.0, 0.0), "fear": 0.0}]
	return is_equal_approx(CrowdPanic.propagated_fear(Vector3.ZERO, calm, 5.0, 1.0), 0.0)


func test_propagated_zero_from_distant_neighbors() -> bool:
	var distant := [{"pos": Vector3(9.0, 0.0, 0.0), "fear": 1.0}]
	return is_equal_approx(CrowdPanic.propagated_fear(Vector3.ZERO, distant, 5.0, 1.0), 0.0)


func test_propagated_saturates_at_one() -> bool:
	# A pile of terrified neighbours on top of the ped must not exceed 1.0.
	var mob := [
		{"pos": Vector3(0.5, 0.0, 0.0), "fear": 1.0},
		{"pos": Vector3(-0.5, 0.0, 0.0), "fear": 1.0},
		{"pos": Vector3(0.0, 0.0, 0.5), "fear": 1.0},
		{"pos": Vector3(0.0, 0.0, -0.5), "fear": 1.0},
	]
	return is_equal_approx(CrowdPanic.propagated_fear(Vector3.ZERO, mob, 5.0, 1.0), 1.0)


func test_propagated_empty_neighbors() -> bool:
	return is_equal_approx(CrowdPanic.propagated_fear(Vector3.ZERO, [], 5.0, 1.0), 0.0)


# --- step_fear ---------------------------------------------------------------


func test_step_fear_raises_to_external() -> bool:
	# Calm ped, fresh fear of 0.8, no decay this instant.
	return is_equal_approx(CrowdPanic.step_fear(0.0, 0.8, 0.0, 0.0), 0.8)


func test_step_fear_keeps_higher_current() -> bool:
	# Already more scared than the incoming jolt -> stays put (then no decay).
	return is_equal_approx(CrowdPanic.step_fear(0.9, 0.4, 0.0, 0.0), 0.9)


func test_step_fear_decays_over_time() -> bool:
	# 1.0 fear, decay 0.5/s, 1s, no new input -> 0.5.
	return is_equal_approx(CrowdPanic.step_fear(1.0, 0.0, 0.5, 1.0), 0.5)


func test_step_fear_decays_to_zero_floor() -> bool:
	# Over-decay clamps at 0, the crowd calms completely.
	return is_equal_approx(CrowdPanic.step_fear(0.2, 0.0, 0.5, 1.0), 0.0)


func test_step_fear_clamps_high() -> bool:
	return is_equal_approx(CrowdPanic.step_fear(1.0, 5.0, 0.0, 0.0), 1.0)


# --- flee_direction ----------------------------------------------------------


func test_flee_points_away_from_scare() -> bool:
	# Scare to the west, ped flees east.
	var dir := CrowdPanic.flee_direction(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, [], 2.0)
	return is_equal_approx(dir.x, 1.0) and is_equal_approx(dir.z, 0.0)


func test_flee_is_normalized() -> bool:
	var neighbors := [{"pos": Vector3(4.5, 0.0, 1.0), "fear": 1.0}]
	var dir := CrowdPanic.flee_direction(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, neighbors, 3.0)
	return is_equal_approx(dir.length(), 1.0)


func test_flee_degenerate_falls_back() -> bool:
	# Standing on the scare with no neighbours -> still a valid unit heading.
	var dir := CrowdPanic.flee_direction(Vector3.ZERO, Vector3.ZERO, [], 2.0)
	return is_equal_approx(dir.length(), 1.0)


func test_flee_separation_fans_crowd() -> bool:
	# A neighbour off to one side nudges the flee heading sideways from pure-away.
	var neighbor := [{"pos": Vector3(5.0, 0.0, 1.0), "fear": 1.0}]
	var dir := CrowdPanic.flee_direction(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, neighbor, 3.0)
	return dir.z < 0.0 and is_equal_approx(dir.length(), 1.0)


# --- is_panicking ------------------------------------------------------------


func test_is_panicking_threshold() -> bool:
	return (
		CrowdPanic.is_panicking(0.6, 0.5)
		and CrowdPanic.is_panicking(0.5, 0.5)
		and not CrowdPanic.is_panicking(0.49, 0.5)
	)


# --- update_crowd : the wave -------------------------------------------------


func test_update_crowd_wave_reaches_far_ped() -> bool:
	# Three peds in a line out from a scare at the origin.
	#   A @ 3m  — inside the 6m scare, lights up on tick 1.
	#   B @ 9m  — outside the scare, but within 5m contagion of A (gap 6m? no:
	#             B-A gap is 6m, so widen via the mid ped). Use a chain:
	#   Layout: A@2, B@6, C@10. scare_radius 4 -> only A is directly scared.
	#   contagion_radius 5 -> A->B (gap 4) reachable, B->C (gap 4) reachable,
	#   A->C (gap 8) NOT. So C can only catch fear second-hand, after B does.
	var peds: Array = [
		{"pos": Vector3(2.0, 0.0, 0.0), "fear": 0.0},  # A near
		{"pos": Vector3(6.0, 0.0, 0.0), "fear": 0.0},  # B mid
		{"pos": Vector3(10.0, 0.0, 0.0), "fear": 0.0},  # C far
	]

	# Decay 0 here so the faint second-hand fear isn't wiped before it can travel
	# the chain — we're asserting the WAVE arrives, not the cooling (step_fear
	# tests cover decay). Contagion 1.0 strength, 5m reach.
	# Tick 1: A scared directly; B/C still calm (A's CURRENT fear was 0).
	var t1 := CrowdPanic.update_crowd(peds, Vector3.ZERO, 4.0, 5.0, 1.0, 0.0, 1.0)
	peds[0]["fear"] = t1[0]
	peds[1]["fear"] = t1[1]
	peds[2]["fear"] = t1[2]
	var a_scared: bool = t1[0] > 0.4
	var b_calm_t1: bool = t1[1] < 0.01
	var c_calm_t1: bool = t1[2] < 0.01

	# Tick 2: B catches A's fear; C still calm (B only just lit up this tick).
	var t2 := CrowdPanic.update_crowd(peds, Vector3.ZERO, 4.0, 5.0, 1.0, 0.0, 1.0)
	peds[0]["fear"] = t2[0]
	peds[1]["fear"] = t2[1]
	peds[2]["fear"] = t2[2]
	var b_scared_t2: bool = t2[1] > 0.0
	var c_calm_t2: bool = t2[2] < 0.01

	# Tick 3: the wave reaches C.
	var t3 := CrowdPanic.update_crowd(peds, Vector3.ZERO, 4.0, 5.0, 1.0, 0.0, 1.0)
	var c_scared_t3: bool = t3[2] > 0.0

	return a_scared and b_calm_t1 and c_calm_t1 and b_scared_t2 and c_calm_t2 and c_scared_t3


func test_update_crowd_isolated_ped_stays_calm() -> bool:
	# A ped far beyond the scare AND beyond contagion of anyone never panics.
	var peds: Array = [
		{"pos": Vector3(0.0, 0.0, 0.0), "fear": 0.0},  # scared directly
		{"pos": Vector3(100.0, 0.0, 0.0), "fear": 0.0},  # marooned far away
	]
	var calm := true
	for _i in 5:
		var out := CrowdPanic.update_crowd(peds, Vector3.ZERO, 4.0, 5.0, 1.0, 0.05, 1.0)
		peds[0]["fear"] = out[0]
		peds[1]["fear"] = out[1]
		if out[1] > 0.0:
			calm = false
	return calm


func test_update_crowd_returns_one_fear_per_ped() -> bool:
	var peds: Array = [
		{"pos": Vector3(1.0, 0.0, 0.0), "fear": 0.0},
		{"pos": Vector3(2.0, 0.0, 0.0), "fear": 0.0},
	]
	var out := CrowdPanic.update_crowd(peds, Vector3.ZERO, 4.0, 5.0, 1.0, 0.05, 1.0)
	return out.size() == 2
