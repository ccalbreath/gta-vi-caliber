class_name ExplosionMath
extends RefCounted
## Pure radial blast-damage falloff.
##
## Full damage within inner_radius, linear falloff to zero at outer_radius,
## nothing beyond. Scene-free so Grenade (and future rockets/car bombs) share
## one tested curve (tests/unit/test_explosion_math.gd).


static func radial_damage(
	distance: float, inner_radius: float, outer_radius: float, max_damage: float
) -> float:
	# Degenerate/inverted radii describe no real blast volume → no damage, even
	# at the centre. Checked first so it wins over the full-damage inner case.
	if outer_radius <= inner_radius:
		return 0.0
	if distance <= inner_radius:
		return max_damage
	if distance >= outer_radius:
		return 0.0
	var t := (distance - inner_radius) / (outer_radius - inner_radius)
	return max_damage * (1.0 - t)
