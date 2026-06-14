class_name ExplosionModel
extends RefCounted
## Pure radial-blast model — damage, knockback, and chain reactions.
##
## Full 3D (verticality matters: a grenade under a balcony still lifts bodies),
## scene-free, all static, Vector3-in / Vector3-out. Grenades, car explosions,
## and barrel chains feed it positions; it returns numbers a node applies to a
## CharacterBody3D / Hittable. Unit-tested headless
## (tests/unit/test_explosion_model.gd).
##
## ExplosionMath already owns a simple inner/outer-radius damage curve for the
## grenade; this is the broader physics model (knockback + chaining +
## batch queries) that the wider blast system needs. Distinct on purpose.
##
## Falloff curve: LINEAR. value = 1 at the centre, ramps straight down to 0 at
## `radius`, 0 beyond. Linear (not smoothstep) so it matches ExplosionMath and
## stays trivially predictable for designers tuning grenade/car blast feel.

## Fraction of the remaining (distance-scaled) impulse added straight up, so
## bodies pop into the air instead of only sliding along the ground.
const UPWARD_BIAS: float = 0.35


## The shared 0..1 falloff: 1 at the centre, linearly to 0 at `radius`, clamped
## both ends. A non-positive radius is a degenerate blast → always 0.
static func falloff(distance: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	if distance <= 0.0:
		return 1.0
	if distance >= radius:
		return 0.0
	return 1.0 - distance / radius


## True while `target_pos` sits strictly inside the blast sphere. The boundary
## (distance == radius) is out — falloff is already 0 there.
static func is_in_blast(center: Vector3, target_pos: Vector3, radius: float) -> bool:
	if radius <= 0.0:
		return false
	return center.distance_to(target_pos) < radius


## Damage dealt to a target: `max_damage` at the centre, linearly to 0 at
## `radius`, 0 beyond. Never negative (max_damage is floored at 0).
static func damage_at(
	center: Vector3, target_pos: Vector3, max_damage: float, radius: float
) -> float:
	var dist := center.distance_to(target_pos)
	return maxf(max_damage, 0.0) * falloff(dist, radius)


## Outward knockback impulse: away from `center`, magnitude `max_impulse` at the
## centre falling to 0 at `radius`, plus an upward bias so bodies are lifted.
## Returns ZERO when the target is exactly at the centre (no direction → no NaN)
## or at/beyond the radius.
static func knockback(
	center: Vector3, target_pos: Vector3, max_impulse: float, radius: float
) -> Vector3:
	var to := target_pos - center
	var dist := to.length()
	# At the dead centre there is no outward direction; spare the NaN and let the
	# vertical bias still throw the body straight up.
	if dist < 0.0001:
		var f_center := falloff(0.0, radius)
		return Vector3.UP * (maxf(max_impulse, 0.0) * f_center * UPWARD_BIAS)
	var f := falloff(dist, radius)
	if f <= 0.0:
		return Vector3.ZERO
	var strength := maxf(max_impulse, 0.0) * f
	var outward := to / dist
	return outward * strength + Vector3.UP * (strength * UPWARD_BIAS)


## Whether this blast detonates a nearby explosive (car, barrel) sitting at
## `other_explosive_pos`, driving chain reactions. True within `trigger_radius`
## (inclusive — a touching gas tank should go), false beyond.
static func should_chain(
	center: Vector3, other_explosive_pos: Vector3, trigger_radius: float
) -> bool:
	if trigger_radius <= 0.0:
		return false
	return center.distance_to(other_explosive_pos) <= trigger_radius


## Batch damage query: every target inside the blast, as
## [{ "index": int, "damage": float }, ...]. Targets at/beyond the radius are
## omitted (they take nothing), so callers iterate only on real hits. Non-Vector3
## entries are skipped defensively.
static func apply_to_many(
	center: Vector3, targets: Array, max_damage: float, radius: float
) -> Array:
	var hits: Array = []
	for i in targets.size():
		var entry: Variant = targets[i]
		if not (entry is Vector3):
			continue
		var pos: Vector3 = entry
		if not is_in_blast(center, pos, radius):
			continue
		hits.append({"index": i, "damage": damage_at(center, pos, max_damage, radius)})
	return hits
