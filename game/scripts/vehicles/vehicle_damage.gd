class_name VehicleDamage
extends RefCounted
## Pure mechanical-damage math for vehicles (roadmap M2: mechanical state
## first, visual deformation later).
##
## Static functions only, no scene access — same testable-core pattern as
## VehicleMotion. Covered by tests/unit/test_vehicle_damage.gd.


## Damage for a single-tick velocity change. Changes below the threshold
## (normal driving, braking, landings) are free; past it, damage scales
## linearly with crash severity.
static func impact_damage(velocity_change: float, threshold: float, scale: float) -> float:
	if velocity_change <= threshold:
		return 0.0
	return (velocity_change - threshold) * scale


## Health left after taking damage; never below zero.
static func health_after(health: float, damage: float) -> float:
	return maxf(health - damage, 0.0)


## Engine output multiplier for a health fraction: 1.0 pristine, easing
## down to limp_floor when barely alive, and 0.0 (dead engine) at zero.
static func engine_multiplier(health: float, max_health: float, limp_floor: float) -> float:
	if max_health <= 0.0 or health <= 0.0:
		return 0.0
	return lerpf(limp_floor, 1.0, clampf(health / max_health, 0.0, 1.0))
