class_name Buoyancy
extends RefCounted
## Multi-probe buoyancy math — floats a rigid body on the Gerstner ocean by
## sampling the surface under several points on the hull and pushing each up in
## proportion to how deep it is. Several probes (not one) is what gives free
## self-righting: a tilted-under corner gets shoved up harder than the others.
##
## Pure and deterministic (depths + params → forces), so it unit-tests headless
## (tests/unit/test_buoyancy.gd). The Floater node does the sampling and applies
## the forces; this is just the numbers.


## How far a probe at `probe_y` sits below the water surface `water_y` (0 if above).
static func submersion(probe_y: float, water_y: float) -> float:
	return maxf(water_y - probe_y, 0.0)


## Upward force at one probe: proportional to submersion, saturating at
## `max_depth` so a fully-dunked body doesn't get launched out of the sea.
static func probe_force(submersion_depth: float, strength: float, max_depth: float = 2.0) -> float:
	return clampf(submersion_depth, 0.0, max_depth) * strength


## Sum of probe forces over a set of submersion depths.
static func net_force(depths: Array, strength: float, max_depth: float = 2.0) -> float:
	var f := 0.0
	for d in depths:
		f += probe_force(float(d), strength, max_depth)
	return f


## Fraction of probes underwater — scales damping and answers "is it floating".
static func submerged_fraction(depths: Array) -> float:
	if depths.is_empty():
		return 0.0
	var n := 0
	for d in depths:
		if float(d) > 0.0:
			n += 1
	return float(n) / float(depths.size())


## Vertical drag opposing velocity while submerged (kills the bob so a boat
## settles instead of pogoing). Scaled by how much of it is in the water.
static func vertical_drag(velocity_y: float, submerged: float, drag: float) -> float:
	return -velocity_y * drag * clampf(submerged, 0.0, 1.0)
