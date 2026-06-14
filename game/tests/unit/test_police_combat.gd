extends RefCounted
## Unit tests for PoliceCombat (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass). All assertions hit the pure PoliceCombat
## + CombatAi + PoliceResponse composition — no scene, no node, headless-safe.

const FWD := Vector3(1, 0, 0)
const BACK := Vector3(-1, 0, 0)

# --- plan: positioning vs firing -----------------------------------------


func test_far_target_advances_without_firing() -> bool:
	# 40m is well beyond the band (~[11.5, 20.5]) → close in, hold fire.
	var p := PoliceCombat.plan(40.0, true, FWD, FWD, 1.0, 3, 12, true)
	return p["action"] == CombatAi.Action.ADVANCE and not bool(p["fire"])


func test_in_band_aimed_engages_and_fires() -> bool:
	var p := PoliceCombat.plan(16.0, true, FWD, FWD, 1.0, 3, 12, true)
	return p["action"] == CombatAi.Action.ENGAGE and bool(p["fire"])


func test_engage_holds_fire_until_cooldown_ready() -> bool:
	var p := PoliceCombat.plan(16.0, true, FWD, FWD, 1.0, 3, 12, false)
	return p["action"] == CombatAi.Action.ENGAGE and not bool(p["fire"])


func test_no_line_of_sight_advances_never_fires() -> bool:
	# Aimed and in range, but a wall is in the way → move, do not shoot through it.
	var p := PoliceCombat.plan(16.0, false, FWD, FWD, 1.0, 3, 12, true)
	return p["action"] == CombatAi.Action.ADVANCE and not bool(p["fire"])


func test_out_of_arc_repositions_without_firing() -> bool:
	# In band and visible, but not yet turned toward the target.
	var p := PoliceCombat.plan(16.0, true, FWD, BACK, 1.0, 3, 12, true)
	return (
		p["action"] == CombatAi.Action.REPOSITION and not bool(p["fire"]) and not bool(p["in_arc"])
	)


# --- plan: survival & ammo ------------------------------------------------


func test_hurt_takes_cover_unless_lethal_heat() -> bool:
	var timid := PoliceCombat.plan(16.0, true, FWD, FWD, 0.3, 2, 12, true)
	# 5-star heat (aggression 1.0) presses the attack even while hurt.
	var lethal := PoliceCombat.plan(16.0, true, FWD, FWD, 0.3, 5, 12, true)
	return (
		timid["action"] == CombatAi.Action.TAKE_COVER
		and lethal["action"] != CombatAi.Action.TAKE_COVER
	)


func test_out_of_ammo_branches_on_heat() -> bool:
	var lethal := PoliceCombat.plan(16.0, true, FWD, FWD, 1.0, 5, 0, true)
	var timid := PoliceCombat.plan(16.0, true, FWD, FWD, 1.0, 1, 0, true)
	# Relentless responders break contact to reload; timid ones fall back.
	return (
		lethal["action"] == CombatAi.Action.REPOSITION
		and timid["action"] == CombatAi.Action.RETREAT
	)


# --- heat scaling ---------------------------------------------------------


func test_fire_cooldown_shrinks_with_heat() -> bool:
	var hot := PoliceCombat.fire_cooldown(5)
	var cold := PoliceCombat.fire_cooldown(1)
	return hot > 0.0 and cold > 0.0 and hot < cold


func test_chase_speed_grows_with_heat() -> bool:
	return PoliceCombat.chase_speed(7.0, 5) > PoliceCombat.chase_speed(7.0, 0)


func test_zero_stars_is_calm_and_slow() -> bool:
	var p := PoliceCombat.plan(40.0, true, FWD, FWD, 1.0, 0, 12, true)
	if p["action"] != CombatAi.Action.ADVANCE or bool(p["fire"]):
		return false
	# Calmest heat → longest fire interval and slowest chase.
	var slowest_fire := PoliceCombat.fire_cooldown(0) >= PoliceCombat.fire_cooldown(5)
	var slowest_chase := PoliceCombat.chase_speed(7.0, 0) <= PoliceCombat.chase_speed(7.0, 5)
	return slowest_fire and slowest_chase


# --- band sanity ----------------------------------------------------------


func test_band_brackets_preferred_range() -> bool:
	var b := PoliceCombat.band()
	return b.x < PoliceCombat.PREFERRED_RANGE and b.y > PoliceCombat.PREFERRED_RANGE
