class_name MissionFlow
extends RefCounted
## Pure sequencing + fail-condition helpers layered on MissionObjectives.
##
## MissionObjectives owns the objective set and done-flags; this decides which
## objective is CURRENT (GTA shows one at a time with a waypoint), formats the HUD
## line, and answers whether a fail condition (timer, player death) has tripped.
## Static, scene-free, RNG-free — unit-tested headless
## (tests/unit/test_mission_flow.gd). `objectives` is the Array of
## {id, text, done} dictionaries a MissionObjectives exposes.

const NO_INDEX := -1


## Index of the first not-yet-done objective, or NO_INDEX if all are done/empty.
static func current_index(objectives: Array) -> int:
	for i in objectives.size():
		if not objectives[i].get("done", false):
			return i
	return NO_INDEX


## The current objective dict ({id,text,done}), or {} when none remain.
static func current(objectives: Array) -> Dictionary:
	var i := current_index(objectives)
	return objectives[i] if i != NO_INDEX else {}


## Display text of the current objective, or "" when none remain.
static func current_text(objectives: Array) -> String:
	var o := current(objectives)
	return String(o.get("text", "")) if not o.is_empty() else ""


## How many objectives are done.
static func done_count(objectives: Array) -> int:
	var n := 0
	for o in objectives:
		if o.get("done", false):
			n += 1
	return n


## One HUD line: "TITLE — <current objective> (k/n)", or "… — complete (n/n)".
static func hud_line(title: String, objectives: Array) -> String:
	var total := objectives.size()
	var done := done_count(objectives)
	var text := current_text(objectives)
	if text.is_empty():
		return "%s — complete (%d/%d)" % [title, done, total]
	return "%s — %s (%d/%d)" % [title, text, done + 1, total]


## True once a timed mission's clock has run out (untimed missions never time out).
static func timed_out(time_limit: float, time_left: float) -> bool:
	return time_limit > 0.0 and time_left <= 0.0


## Whether the mission should fail this tick: player death always fails it; a
## timed mission also fails when the clock hits zero.
static func should_fail(player_dead: bool, time_limit: float, time_left: float) -> bool:
	return player_dead or timed_out(time_limit, time_left)


## World waypoint for the current objective from an id → Vector3 map, falling back
## to `fallback` when there is no current objective or it has no mapped point.
static func current_waypoint(
	objectives: Array, waypoints: Dictionary, fallback: Vector3
) -> Vector3:
	var o := current(objectives)
	if o.is_empty():
		return fallback
	return waypoints.get(String(o.get("id", "")), fallback)
