class_name PursuitMemory
extends RefCounted
## Pure pursuit-memory for a chasing officer: where to move when the target is in
## or out of sight, and when to abandon the chase. This is what makes the "go
## cold" evasion loop real — without it police steer to the player's exact live
## position every tick, tracking them perfectly through walls so they can never
## be shaken.
##
## Static, scene-free, RNG injected by the caller. The Police node holds the
## mutable state (last-known point, seconds-unseen, engaged flag) and feeds these
## helpers. "Planar" is the XZ plane, matching CombatAi / NpcBrain.

enum State { PURSUE, SEARCH, LOST }

## Default radius an officer mills around the last-known point while searching.
const SEARCH_RADIUS := 6.0


## Where to steer: the live target while it is in sight, else its last-known spot.
static func target(seen: bool, target_pos: Vector3, last_known: Vector3) -> Vector3:
	return target_pos if seen else last_known


## True once the target has been out of sight long enough to abandon the chase.
## give_up_time <= 0 disables giving up (relentless).
static func should_give_up(time_unseen: float, give_up_time: float) -> bool:
	return give_up_time > 0.0 and time_unseen >= give_up_time


## Classify the chase: in sight → PURSUE; lost too long → LOST; otherwise SEARCH
## once the officer has reached the last-known point, else PURSUE (still en route).
static func state(
	seen: bool, time_unseen: float, reached_last_known: bool, give_up_time: float
) -> State:
	if seen:
		return State.PURSUE
	if should_give_up(time_unseen, give_up_time):
		return State.LOST
	return State.SEARCH if reached_last_known else State.PURSUE


## A point to sweep while searching near the last-known position — area-uniform
## within `radius` (like NpcBrain.wander_target). u_radius, u_angle in [0, 1).
static func search_point(
	last_known: Vector3, u_radius: float, u_angle: float, radius: float = SEARCH_RADIUS
) -> Vector3:
	var r := sqrt(clampf(u_radius, 0.0, 1.0)) * radius
	var a := u_angle * TAU
	return last_known + Vector3(cos(a) * r, 0.0, sin(a) * r)
