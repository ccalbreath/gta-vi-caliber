class_name PoliceCombat
extends RefCounted
## Pure composition layer that turns wanted-level heat into a police gunfight.
##
## It wires together two existing pure models so the Police node has ONE call and
## the composition itself is unit-tested (tests/unit/test_police_combat.gd):
##   - CombatAi      — the tactical decision brain (advance/engage/reposition/…)
##   - PoliceResponse — maps wanted stars → aggression (fire rate, chase speed)
##
## Static functions only, no scene/RNG/node state, "planar" = XZ with y ignored —
## same convention as CombatAi / NpcBrain / PoliceResponse. The Police node owns
## the mutable state (fire cooldown, ammo, aim heading) and just executes the plan.

## Seconds between shots at neutral aggression, before heat scaling.
const BASE_FIRE_INTERVAL := 1.1
## A pistol's comfortable engagement distance — cops hold here and fire.
const PREFERRED_RANGE := 16.0
## Half-width of the engagement band as a fraction of PREFERRED_RANGE.
const BAND_HYSTERESIS := 0.28
## Chase speed multipliers at minimum (calm) and maximum (lethal) aggression.
const CHASE_SPEED_MIN_SCALE := 0.85
const CHASE_SPEED_MAX_SCALE := 1.25


## The engagement distance band cops try to hold around PREFERRED_RANGE.
static func band() -> Vector2:
	return CombatAi.engagement_band(PREFERRED_RANGE, BAND_HYSTERESIS)


## The whole per-tick decision for one officer, as a small deterministic record:
##   action     — CombatAi.Action to execute this tick
##   fire       — true iff the officer should pull the trigger now
##   in_arc     — whether the target is within the firing arc (for debugging/feel)
##   aggression — the heat-derived aggression in [0, 1]
## `facing` and `to_target_dir` are planar unit headings; the node supplies its
## current aim heading and the direction to the player. `cooldown_ready` is true
## once the per-officer fire timer has elapsed.
static func plan(
	distance: float,
	los_clear: bool,
	facing: Vector3,
	to_target_dir: Vector3,
	health_frac: float,
	stars: int,
	ammo: int,
	cooldown_ready: bool
) -> Dictionary:
	var aggression := PoliceResponse.aggression(stars)
	var in_arc := CombatAi.in_firing_arc(facing, to_target_dir, CombatAi.DEFAULT_ARC_HALF)
	var action := CombatAi.decide_action(
		distance, band(), los_clear, in_arc, health_frac, aggression, ammo
	)
	return {
		"action": action,
		"fire": CombatAi.should_fire(action, cooldown_ready),
		"in_arc": in_arc,
		"aggression": aggression,
	}


## Seconds to wait before the next shot, scaled by heat — higher wanted levels
## make responders fire faster (CombatAi.fire_interval shrinks with aggression).
static func fire_cooldown(stars: int) -> float:
	return CombatAi.fire_interval(BASE_FIRE_INTERVAL, PoliceResponse.aggression(stars))


## Chase speed for the given base run speed, scaled by heat so a 5-star response
## closes faster than a 1-star one.
static func chase_speed(base_run: float, stars: int) -> float:
	return (
		base_run
		* lerpf(CHASE_SPEED_MIN_SCALE, CHASE_SPEED_MAX_SCALE, PoliceResponse.aggression(stars))
	)
