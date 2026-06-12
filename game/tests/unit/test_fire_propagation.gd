extends RefCounted
## Unit tests for FirePropagation (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). Deterministic, concrete 3D coords.

# --- ignite_intensity -------------------------------------------------------


func test_ignite_full_at_source() -> bool:
	var here := Vector3(10.0, 0.0, 10.0)
	return is_equal_approx(FirePropagation.ignite_intensity(here, here, 5.0), 1.0)


func test_ignite_falls_off_with_distance() -> bool:
	var src := Vector3(0.0, 0.0, 0.0)
	var tgt := Vector3(2.0, 0.0, 0.0)
	# 1 - 2/4 = 0.5
	return is_equal_approx(FirePropagation.ignite_intensity(src, tgt, 4.0), 0.5)


func test_ignite_zero_beyond_radius() -> bool:
	var src := Vector3.ZERO
	var tgt := Vector3(6.0, 0.0, 0.0)
	return is_equal_approx(FirePropagation.ignite_intensity(src, tgt, 5.0), 0.0)


func test_ignite_uses_full_3d_distance() -> bool:
	var src := Vector3.ZERO
	var tgt := Vector3(0.0, 4.0, 0.0)
	# vertical 4 with radius 8 -> 1 - 4/8 = 0.5 (height counts)
	return is_equal_approx(FirePropagation.ignite_intensity(src, tgt, 8.0), 0.5)


func test_ignite_guards_bad_radius() -> bool:
	return is_equal_approx(FirePropagation.ignite_intensity(Vector3.ZERO, Vector3.ONE, 0.0), 0.0)


# --- spread_intensity -------------------------------------------------------


func test_spread_catches_from_near_hot_neighbor() -> bool:
	var tgt := Vector3.ZERO
	var hot := [{"pos": Vector3(2.0, 0.0, 0.0), "intensity": 1.0}]
	# proximity 1-2/4=0.5, *intensity 1 *rate 2 *delta 0.5 = 0.5
	var caught: float = FirePropagation.spread_intensity(tgt, hot, 4.0, 2.0, 0.5)
	return is_equal_approx(caught, 0.5)


func test_spread_more_from_hotter_neighbor() -> bool:
	var tgt := Vector3.ZERO
	var cool := [{"pos": Vector3(1.0, 0.0, 0.0), "intensity": 0.3}]
	var hot := [{"pos": Vector3(1.0, 0.0, 0.0), "intensity": 0.9}]
	var c1: float = FirePropagation.spread_intensity(tgt, cool, 5.0, 1.0, 1.0)
	var c2: float = FirePropagation.spread_intensity(tgt, hot, 5.0, 1.0, 1.0)
	return c2 > c1


func test_spread_zero_from_cold_neighbor() -> bool:
	var tgt := Vector3.ZERO
	var cold := [{"pos": Vector3(1.0, 0.0, 0.0), "intensity": 0.0}]
	return is_equal_approx(FirePropagation.spread_intensity(tgt, cold, 5.0, 1.0, 1.0), 0.0)


func test_spread_zero_from_distant_neighbor() -> bool:
	var tgt := Vector3.ZERO
	var far := [{"pos": Vector3(20.0, 0.0, 0.0), "intensity": 1.0}]
	return is_equal_approx(FirePropagation.spread_intensity(tgt, far, 5.0, 1.0, 1.0), 0.0)


func test_spread_saturates_at_one() -> bool:
	var tgt := Vector3.ZERO
	var many := [
		{"pos": Vector3(0.5, 0.0, 0.0), "intensity": 1.0},
		{"pos": Vector3(0.0, 0.0, 0.5), "intensity": 1.0},
		{"pos": Vector3(0.5, 0.0, 0.5), "intensity": 1.0},
	]
	var caught: float = FirePropagation.spread_intensity(tgt, many, 4.0, 5.0, 1.0)
	return is_equal_approx(caught, 1.0)


# --- step_intensity ---------------------------------------------------------


func test_step_grows_while_fuel_remains() -> bool:
	# current 0.2, incoming 0, growth 0.5, delta 1 -> 0.7, fuel present
	var out: float = FirePropagation.step_intensity(0.2, 0.0, 0.5, 0.3, 10.0, 1.0)
	return is_equal_approx(out, 0.7)


func test_step_floor_is_max_of_current_and_incoming() -> bool:
	# incoming 0.6 raises a cooler current 0.1, then grows 0.2 -> 0.8
	var out: float = FirePropagation.step_intensity(0.1, 0.6, 0.2, 0.3, 5.0, 1.0)
	return is_equal_approx(out, 0.8)


func test_step_decays_when_fuel_gone() -> bool:
	# fuel 0 -> decay: 0.9 - burnout 0.4*delta 1 = 0.5
	var out: float = FirePropagation.step_intensity(0.9, 0.0, 0.5, 0.4, 0.0, 1.0)
	return is_equal_approx(out, 0.5)


func test_step_clamps_to_one() -> bool:
	var out: float = FirePropagation.step_intensity(0.9, 0.0, 1.0, 0.0, 10.0, 1.0)
	return is_equal_approx(out, 1.0)


func test_step_decay_floors_at_zero() -> bool:
	var out: float = FirePropagation.step_intensity(0.1, 0.0, 0.0, 5.0, 0.0, 1.0)
	return is_equal_approx(out, 0.0)


# --- fuel_step --------------------------------------------------------------


func test_fuel_depletes_faster_when_hotter() -> bool:
	var lo: float = FirePropagation.fuel_step(10.0, 0.25, 4.0, 1.0)
	var hi: float = FirePropagation.fuel_step(10.0, 1.0, 4.0, 1.0)
	# lo: 10 - 4*0.25 = 9 ; hi: 10 - 4*1 = 6
	return is_equal_approx(lo, 9.0) and is_equal_approx(hi, 6.0)


func test_fuel_floors_at_zero() -> bool:
	var out: float = FirePropagation.fuel_step(0.5, 1.0, 10.0, 1.0)
	return is_equal_approx(out, 0.0)


func test_fuel_unchanged_when_cold() -> bool:
	var out: float = FirePropagation.fuel_step(7.0, 0.0, 5.0, 1.0)
	return is_equal_approx(out, 7.0)


# --- flags ------------------------------------------------------------------


func test_is_burning_threshold() -> bool:
	return (
		FirePropagation.is_burning(0.3, 0.25)
		and FirePropagation.is_burning(0.25, 0.25)
		and not FirePropagation.is_burning(0.1, 0.25)
	)


func test_is_burnt_out_threshold() -> bool:
	return FirePropagation.is_burnt_out(0.0) and not FirePropagation.is_burnt_out(0.01)


# --- damage_per_second ------------------------------------------------------


func test_damage_scales_with_intensity() -> bool:
	return (
		is_equal_approx(FirePropagation.damage_per_second(1.0, 40.0), 40.0)
		and is_equal_approx(FirePropagation.damage_per_second(0.5, 40.0), 20.0)
		and is_equal_approx(FirePropagation.damage_per_second(0.0, 40.0), 0.0)
	)


# --- update_fires (the chain) -----------------------------------------------


func test_update_spreads_to_adjacent_keeps_distant_cold() -> bool:
	# A burning car at origin, an adjacent flammable 1.5m away, a distant one 40m away.
	var objects: Array = [
		{"pos": Vector3(0.0, 0.0, 0.0), "intensity": 1.0, "fuel": 100.0},
		{"pos": Vector3(1.5, 0.0, 0.0), "intensity": 0.0, "fuel": 100.0},
		{"pos": Vector3(40.0, 0.0, 0.0), "intensity": 0.0, "fuel": 100.0},
	]
	var next: Array = FirePropagation.update_fires(objects, 5.0, 2.0, 0.3, 0.4, 1.0, 1.0)
	var adjacent: Dictionary = next[1]
	var distant: Dictionary = next[2]
	var adj_i: float = adjacent["intensity"]
	var dist_i: float = distant["intensity"]
	return adj_i > 0.0 and is_equal_approx(dist_i, 0.0)


func test_update_fire_grows_over_ticks() -> bool:
	var objects: Array = [
		{"pos": Vector3(0.0, 0.0, 0.0), "intensity": 1.0, "fuel": 100.0},
		{"pos": Vector3(1.0, 0.0, 0.0), "intensity": 0.0, "fuel": 100.0},
	]
	# Gentle spread rate so the catch ramps over ticks instead of saturating in one.
	var after1: Array = FirePropagation.update_fires(objects, 5.0, 0.3, 0.3, 0.4, 1.0, 1.0)
	var after2: Array = FirePropagation.update_fires(
		_carry_pos(after1, objects), 5.0, 0.3, 0.3, 0.4, 1.0, 1.0
	)
	var i1: float = (after1[1] as Dictionary)["intensity"]
	var i2: float = (after2[1] as Dictionary)["intensity"]
	return i2 > i1


func test_update_low_fuel_object_burns_out() -> bool:
	# A lone burning object with almost no fuel: fuel hits 0, then it decays to cold.
	var objects: Array = [{"pos": Vector3.ZERO, "intensity": 0.8, "fuel": 0.1}]
	var step: Array = objects
	# Run several ticks; consume_rate empties the tiny fuel, then burnout fades it.
	for _i in range(20):
		step = _carry_pos(FirePropagation.update_fires(step, 5.0, 2.0, 0.3, 0.5, 5.0, 1.0), objects)
	var final_obj: Dictionary = step[0]
	var fuel: float = final_obj["fuel"]
	var intensity: float = final_obj["intensity"]
	return is_equal_approx(fuel, 0.0) and is_equal_approx(intensity, 0.0)


func test_update_burnt_out_does_not_reignite() -> bool:
	# Spent ash (fuel 0) next to a roaring neighbour must stay cold.
	var objects: Array = [
		{"pos": Vector3(0.0, 0.0, 0.0), "intensity": 1.0, "fuel": 100.0},
		{"pos": Vector3(1.0, 0.0, 0.0), "intensity": 0.0, "fuel": 0.0},
	]
	var next: Array = FirePropagation.update_fires(objects, 5.0, 5.0, 0.5, 0.5, 1.0, 1.0)
	var ash: Dictionary = next[1]
	var ash_i: float = ash["intensity"]
	return is_equal_approx(ash_i, 0.0)


# --- helpers (re-attach positions, which update_fires drops) -----------------


## update_fires returns only {intensity, fuel}; re-attach each object's pos from the
## original parallel array so the next tick can still measure neighbour distance.
func _carry_pos(stepped: Array, source: Array) -> Array:
	var rebuilt: Array = []
	for i in stepped.size():
		var s: Dictionary = stepped[i]
		var src: Dictionary = source[i]
		rebuilt.append({"pos": src["pos"], "intensity": s["intensity"], "fuel": s["fuel"]})
	return rebuilt
