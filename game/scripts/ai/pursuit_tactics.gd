class_name PursuitTactics
extends RefCounted
## Pure police-pursuit tactics: turns a cop car's situation versus a fleeing
## target into a driving aim point and a discrete maneuver. This deepens the
## chase beyond a naive beeline — cops lead their target, box it in with
## roadblocks, ram and PIT when the heat is high enough, and back off when the
## wanted level drops or the target slips away.
##
## Static functions only — no scene access, no RNG, no node state — so behaviour
## is deterministic and unit-tested headless (tests/unit/test_pursuit_tactics.gd).
## The owning cop-car node holds mutable state (its body, the wanted level) and
## feeds these helpers each tick. Work happens in the XZ plane (y is up), matching
## CombatAi/NpcSteering; callers get Vector3 aim points back. Everything is
## defensive against zero-length inputs (no NaN, no divide-by-zero).

enum Tactic {
	CHASE,  ## drive to the lead-intercept point — the default pursuit
	RAM,  ## close and aligned with authorisation → slam the target
	BLOCK,  ## set up ahead-and-to-the-side for a roadblock / boxing wall
	PIT,  ## swing alongside to spin the target out
	BACK_OFF,  ## disengage — wanted cleared or target gone
}

## Stars at or above this authorise aggressive contact (ram / PIT). Below it the
## law tails and blocks but won't deliberately wreck the player.
const AGGRESSION_STARS := 3
## Half-angle (radians) of the "lined up" cone for a ram — the target must be
## roughly dead ahead of the pursuer's heading, not off to the side.
const RAM_ARC_HALF := PI * 30.0 / 180.0
## Distance past which a pursuer gives up regardless of stars.
const GIVE_UP_RANGE := 120.0


## Drop the vertical component — cars steer on the ground plane.
static func ground(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Planar unit direction from `a` to `b`, or ZERO if effectively coincident.
static func planar_dir(a: Vector3, b: Vector3) -> Vector3:
	var d := ground(b - a)
	return d.normalized() if d.length() > 0.0001 else Vector3.ZERO


## Lead-pursuit aim point: where to drive to cut the target off, rather than
## where it is right now. Solves an approximate time-to-intercept assuming the
## target holds its current velocity and the pursuer can travel `pursuer_speed`,
## then aims that many seconds ahead. Falls back to the target's position when
## there is no useful solution (target stationary, pursuer can't move, or the
## quadratic has no positive root).
static func intercept_point(
	target_pos: Vector3, target_vel: Vector3, pursuer_pos: Vector3, pursuer_speed: float
) -> Vector3:
	var tv := ground(target_vel)
	var tp := ground(target_pos)
	var pp := ground(pursuer_pos)
	# Nothing to lead if the target is still or we can't chase.
	if tv.length() < 0.0001 or pursuer_speed <= 0.0001:
		return tp
	var to_target := tp - pp
	# Solve |to_target + tv * t| = pursuer_speed * t for the smallest t > 0.
	# Expands to a*t^2 + b*t + c = 0.
	var a := tv.dot(tv) - pursuer_speed * pursuer_speed
	var b := 2.0 * to_target.dot(tv)
	var c := to_target.dot(to_target)
	var t := -1.0
	if absf(a) < 0.0001:
		# Linear case (target speed ≈ pursuer speed).
		if absf(b) > 0.0001:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var root := sqrt(disc)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			# Smallest strictly-positive root.
			t = _smallest_positive(t1, t2)
	if t <= 0.0:
		return tp
	return tp + tv * t


## Smallest strictly-positive of two roots, or -1 if neither qualifies.
static func _smallest_positive(t1: float, t2: float) -> float:
	var lo := minf(t1, t2)
	var hi := maxf(t1, t2)
	if lo > 0.0001:
		return lo
	if hi > 0.0001:
		return hi
	return -1.0


## True only when a ram is justified: the target is within `ram_range`, roughly
## dead ahead of the pursuer's heading, and the wanted level authorises contact
## (`stars` >= AGGRESSION_STARS). All three must hold — a cop won't ram a target
## that's beside it, far off, or at a low wanted level.
static func should_ram(
	pursuer_pos: Vector3,
	pursuer_heading: Vector3,
	target_pos: Vector3,
	ram_range: float,
	stars: int
) -> bool:
	if stars < AGGRESSION_STARS:
		return false
	var to_target := ground(target_pos - pursuer_pos)
	var dist := to_target.length()
	if dist < 0.0001 or dist > ram_range:
		return false
	var heading := ground(pursuer_heading)
	if heading.length() < 0.0001:
		return false
	return heading.normalized().dot(to_target.normalized()) >= cos(RAM_ARC_HALF)


## A point ahead of the target and offset to one `side` (-1 left, +1 right of the
## target's travel direction), at `distance` out — where a unit drives to set up
## a roadblock or pincer wall. If the target isn't moving there's no "ahead", so
## the offset is taken straight to the side of its facing-less position.
static func block_offset(
	target_pos: Vector3, target_vel: Vector3, side: float, distance: float
) -> Vector3:
	var tp := ground(target_pos)
	var fwd := ground(target_vel)
	var s := signf(side) if absf(side) > 0.0001 else 1.0
	if fwd.length() < 0.0001:
		# No travel direction: just step out to the requested side along +X.
		return tp + Vector3(0.0, 0.0, s) * distance
	var dir := fwd.normalized()
	# Right-hand perpendicular on the XZ plane.
	var right := Vector3(dir.z, 0.0, -dir.x)
	# Mostly ahead, partly to the side, so the block sits in the target's path.
	var ahead := dir * distance
	var lateral := right * s * (distance * 0.5)
	return tp + ahead + lateral


## Which side (-1 / +1) the pursuer should swing to for a PIT maneuver: the side
## it is already on relative to the target's direction of travel, so it commits
## to the shorter swing instead of crossing the target's nose. Defaults to +1
## (right) when the geometry is degenerate.
static func pit_side(pursuer_pos: Vector3, target_pos: Vector3, target_vel: Vector3) -> float:
	var fwd := ground(target_vel)
	if fwd.length() < 0.0001:
		return 1.0
	var dir := fwd.normalized()
	var to_pursuer := ground(pursuer_pos - target_pos)
	if to_pursuer.length() < 0.0001:
		return 1.0
	# Right-hand perpendicular; positive projection → pursuer is on the right.
	var right := Vector3(dir.z, 0.0, -dir.x)
	var lateral := to_pursuer.dot(right)
	if absf(lateral) < 0.0001:
		return 1.0
	return signf(lateral)


## Target driving speed for closing a gap: open the throttle when there's
## distance to make up, but ease off when right behind the target so the pursuer
## tucks in to ram/PIT range instead of overshooting. Ramps from `base_speed`
## up to `max_speed` across a closing band, and scales below `base_speed` when
## very close.
static func desired_speed(distance_to_target: float, base_speed: float, max_speed: float) -> float:
	var d := maxf(distance_to_target, 0.0)
	# Right on the bumper: ease off to avoid overshooting past the target.
	var tuck_in := 6.0
	if d < tuck_in:
		return lerpf(base_speed * 0.5, base_speed, d / tuck_in)
	# Beyond the tuck-in zone, climb toward max as the gap widens.
	var full_chase := 40.0
	var t := clampf((d - tuck_in) / (full_chase - tuck_in), 0.0, 1.0)
	return lerpf(base_speed, max_speed, t)


## Whether to disengage: the wanted level has cleared (0 stars) or the target has
## slipped beyond the give-up range. Either ends the pursuit.
static func should_back_off(stars: int, distance: float) -> bool:
	return stars <= 0 or distance > GIVE_UP_RANGE


## Tie it together: pick one tactic for this tick from the full picture. Order is
## a priority ladder — back off first (nothing else matters once the chase is
## over), then ram when lined up and authorised, then PIT when alongside and
## authorised, then block to cut the target off, else plain chase.
static func choose_tactic(
	pursuer_pos: Vector3,
	pursuer_heading: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	stars: int,
	ram_range: float
) -> Tactic:
	var dist := ground(target_pos - pursuer_pos).length()
	if should_back_off(stars, dist):
		return Tactic.BACK_OFF
	if should_ram(pursuer_pos, pursuer_heading, target_pos, ram_range, stars):
		return Tactic.RAM
	# Authorised contact but not lined up head-on: if we're alongside the target
	# (well off its nose), swing for a PIT; otherwise wall it off with a block.
	if stars >= AGGRESSION_STARS and dist <= ram_range * 2.0:
		if _is_alongside(pursuer_pos, target_pos, target_vel):
			return Tactic.PIT
		return Tactic.BLOCK
	return Tactic.CHASE


## True when the pursuer sits off to the target's side (good PIT geometry) rather
## than behind it — lateral offset dominates the along-track offset.
static func _is_alongside(pursuer_pos: Vector3, target_pos: Vector3, target_vel: Vector3) -> bool:
	var fwd := ground(target_vel)
	if fwd.length() < 0.0001:
		return false
	var dir := fwd.normalized()
	var to_pursuer := ground(pursuer_pos - target_pos)
	if to_pursuer.length() < 0.0001:
		return false
	var right := Vector3(dir.z, 0.0, -dir.x)
	var along := to_pursuer.dot(dir)
	var lateral := to_pursuer.dot(right)
	return absf(lateral) >= absf(along)
