class_name NpcBrain
extends RefCounted
## Pure pedestrian AI: wander between points, flee from threats.
##
## Static functions only — no scene access, RNG injected by the caller — so the
## behaviour is deterministic and unit-tested (tests/unit/test_npc_brain.gd).
## The Pedestrian node owns the mutable state (current target, timers) and calls
## these helpers each frame; planar means the XZ plane with y ignored.

enum State { IDLE, WANDER, FLEE }


## A random planar point within `radius` of origin, area-uniform from two
## independent [0, 1) samples so wander targets don't clump at the centre.
static func wander_target(
	origin: Vector3, radius: float, u_radius: float, u_angle: float
) -> Vector3:
	var r := sqrt(clampf(u_radius, 0.0, 1.0)) * radius
	var a := u_angle * TAU
	return origin + Vector3(cos(a) * r, 0.0, sin(a) * r)


## Planar (XZ) distance between two points.
static func planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## True once within `tolerance` (planar) of the target.
static func arrived(pos: Vector3, target: Vector3, tolerance: float) -> bool:
	return planar_distance(pos, target) <= tolerance


## Planar unit direction from a to b, or ZERO if effectively coincident.
static func planar_dir(a: Vector3, b: Vector3) -> Vector3:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	return d.normalized() if d.length() > 0.0001 else Vector3.ZERO


## Direction that runs directly away from a threat (planar, unit).
static func flee_dir(self_pos: Vector3, threat_pos: Vector3) -> Vector3:
	return planar_dir(threat_pos, self_pos)


## Next behaviour state with hysteresis: a nearby active threat forces FLEE; once
## fleeing, keep running until the threat is gone or beyond calm_radius, so the
## pedestrian doesn't flip-flop at the boundary. IDLE/WANDER alternation itself
## is left to the node's timers.
static func next_state(
	current: State,
	threat_active: bool,
	threat_distance: float,
	flee_radius: float,
	calm_radius: float
) -> State:
	if threat_active and threat_distance <= flee_radius:
		return State.FLEE
	if current == State.FLEE and threat_active and threat_distance < calm_radius:
		return State.FLEE
	if current == State.FLEE:
		return State.WANDER
	return current


## Target move speed for a state, given this pedestrian's walk/run speeds.
static func speed_for(state: State, walk_speed: float, run_speed: float) -> float:
	match state:
		State.FLEE:
			return run_speed
		State.WANDER:
			return walk_speed
		_:
			return 0.0
