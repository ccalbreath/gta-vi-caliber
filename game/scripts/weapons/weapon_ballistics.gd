class_name WeaponBallistics
extends RefCounted
## Pure gunplay math a weapon controller applies to each shot: distance falloff,
## hit-zone multipliers, cone spread, and a stateful recoil/bloom accumulator.
##
## The static helpers are scene-free and RNG-free (or take an explicit RNG), so
## they unit-test deterministically (tests/unit/test_weapon_ballistics.gd). This
## complements the lower-level Ballistics (which takes a pre-drawn disk sample):
## here spread_direction draws its own cone offset from a caller-supplied RNG,
## and Bloom carries the per-shot spread growth/recovery across frames the way
## WantedSystem carries heat. Distances are metres, angles radians.

## Default hit-zone multipliers (head rewards precision, limbs punish sloppy aim).
const HEAD_MULTIPLIER: float = 2.0
const TORSO_MULTIPLIER: float = 1.0
const LIMB_MULTIPLIER: float = 0.7


## Damage after distance falloff: full inside falloff_start, lerps down to
## base_damage * min_factor by falloff_end, and never below that floor. min_factor
## is clamped to [0, 1]; a degenerate band (end <= start) snaps to the floor past
## the start. Negative inputs are guarded so damage can't go below zero.
static func damage_at_range(
	base_damage: float, distance: float, falloff_start: float, falloff_end: float, min_factor: float
) -> float:
	var base: float = maxf(base_damage, 0.0)
	var floor_factor: float = clampf(min_factor, 0.0, 1.0)
	var d: float = maxf(distance, 0.0)
	if d <= falloff_start:
		return base
	if d >= falloff_end or falloff_end <= falloff_start:
		return base * floor_factor
	var t: float = (d - falloff_start) / (falloff_end - falloff_start)
	return base * lerpf(1.0, floor_factor, clampf(t, 0.0, 1.0))


## Damage multiplier for the body part a shot landed on. Case-insensitive;
## anything unrecognised (including "") falls back to 1.0 so a missing tag can
## never zero out or inflate damage.
static func hit_multiplier(body_part: String) -> float:
	match body_part.to_lower():
		"head":
			return HEAD_MULTIPLIER
		"torso", "chest", "body":
			return TORSO_MULTIPLIER
		"limb", "arm", "leg":
			return LIMB_MULTIPLIER
		_:
			return 1.0


## Perturb a normalised aim direction by up to spread_radians within a cone and
## return a unit vector. Deterministic given rng. spread <= 0 (or a zero/degenerate
## aim) returns the aim unchanged. The offset is drawn uniformly over the cone's
## base disk via tan(spread), so dot(result, aim) >= cos(spread) always holds.
static func spread_direction(
	aim_dir: Vector3, spread_radians: float, rng: RandomNumberGenerator
) -> Vector3:
	if aim_dir.length() < 0.0001:
		return aim_dir
	var aim: Vector3 = aim_dir.normalized()
	if spread_radians <= 0.0 or rng == null:
		return aim
	# An orthonormal basis spanning the plane perpendicular to aim.
	var helper: Vector3 = Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right: Vector3 = aim.cross(helper).normalized()
	var up: Vector3 = right.cross(aim).normalized()
	# Uniform point in the unit disk (sqrt keeps it area-correct, no centre clump).
	var radius: float = sqrt(rng.randf())
	var angle: float = rng.randf() * TAU
	var offset: Vector3 = (right * cos(angle) + up * sin(angle)) * radius * tan(spread_radians)
	return (aim + offset).normalized()


## Full per-shot damage: range falloff times the hit-zone multiplier. The one call
## a weapon controller makes once it knows distance and where the ray landed.
static func effective_damage(
	base_damage: float,
	distance: float,
	body_part: String,
	falloff_start: float,
	falloff_end: float,
	min_factor: float
) -> float:
	var ranged: float = damage_at_range(
		base_damage, distance, falloff_start, falloff_end, min_factor
	)
	return ranged * hit_multiplier(body_part)


## Seconds to down a target: shots needed (ceil) spread across the fire rate. The
## first shot lands at t=0, so n shots take (n - 1) / fire_rate seconds. Returns
## INF when a shot can't hurt the target (no damage, or non-positive fire rate).
static func time_to_kill(
	effective_damage_per_shot: float, fire_rate: float, target_health: float
) -> float:
	if effective_damage_per_shot <= 0.0 or fire_rate <= 0.0:
		return INF
	if target_health <= 0.0:
		return 0.0
	var shots: int = int(ceil(target_health / effective_damage_per_shot))
	return float(shots - 1) / fire_rate


## Stateful recoil/bloom accumulator: the cone widens as fire is sustained and
## tightens back toward its base while the trigger rests, so tapping stays
## accurate and spraying walks off. An instance per live weapon, like a
## WantedSystem per pursuit.
class Bloom:
	extends RefCounted

	var spread: float
	var min_spread: float
	var max_spread: float
	var per_shot: float
	var recovery: float

	## min/max are the calm and fully-bloomed cone half-angles (rad); per_shot is
	## the bloom added each shot; recovery is how fast the cone shrinks (rad/s).
	## All are clamped non-negative and ordered so min <= max.
	func _init(
		p_min: float = 0.01, p_max: float = 0.16, p_per_shot: float = 0.02, p_recovery: float = 0.22
	) -> void:
		min_spread = maxf(p_min, 0.0)
		max_spread = maxf(p_max, min_spread)
		per_shot = maxf(p_per_shot, 0.0)
		recovery = maxf(p_recovery, 0.0)
		spread = min_spread

	## The cone half-angle to fire the next shot with.
	func current_spread() -> float:
		return spread

	## Register a shot: the cone blooms by per_shot, capped at max_spread.
	func add_shot() -> void:
		spread = minf(spread + per_shot, max_spread)

	## Advance delta seconds of trigger rest: the cone recovers toward min_spread,
	## never dipping below it.
	func recover(delta: float) -> void:
		if delta <= 0.0:
			return
		spread = maxf(spread - recovery * delta, min_spread)

	## Snap back to the calm cone (e.g. on reload or holster).
	func reset() -> void:
		spread = min_spread
