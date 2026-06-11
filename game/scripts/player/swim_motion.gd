class_name SwimMotion
extends RefCounted
## Pure swim math for the player when in water.
##
## Static functions only, no scene access — same testable pattern as
## PlayerMotion (docs/ARCHITECTURE.md). The Player stays thin; this owns
## submersion, the enter/leave hysteresis, stroke input and passive buoyancy.
## Covered by tests/unit/test_swim_motion.gd.


## How far the body is submerged, as a fraction of its height: 0.0 when the
## feet just touch the surface, 1.0 when the head goes under. `origin_y` is the
## body's feet (the CharacterBody3D origin); the body spans up to
## origin_y + body_height. Clamped, and safe for a degenerate height.
static func submersion(origin_y: float, water_y: float, body_height: float) -> float:
	if body_height <= 0.0:
		return 0.0
	return clampf((water_y - origin_y) / body_height, 0.0, 1.0)


## Swim state with hysteresis so the shoreline doesn't flicker between walking
## and swimming as a wave laps the chest. Start swimming once submerged past
## `enter_fraction` (chest-deep); keep swimming until back down past
## `exit_fraction` (wading depth). enter_fraction should exceed exit_fraction.
static func is_swimming(
	submersion_fraction: float, currently: bool, enter_fraction: float, exit_fraction: float
) -> bool:
	if currently:
		return submersion_fraction > exit_fraction
	return submersion_fraction >= enter_fraction


## Vertical stroke axis from the surface/dive keys: +1 kick up, -1 dive down,
## 0 when neither or both are held.
static func vertical_axis(surface_pressed: bool, dive_pressed: bool) -> float:
	return (1.0 if surface_pressed else 0.0) - (1.0 if dive_pressed else 0.0)


## Target swim velocity: the horizontal component follows the camera-relative
## move `direction` at swim_speed, the vertical component is the stroke `axis`
## at vertical_speed. `direction` is the planar unit vector from PlayerMotion.
static func target_velocity(
	direction: Vector3, swim_speed: float, axis: float, vertical_speed: float
) -> Vector3:
	return Vector3(direction.x * swim_speed, axis * vertical_speed, direction.z * swim_speed)


## Passive buoyancy used when no vertical stroke is held: the body eases toward
## floating at `neutral` submersion (e.g. 0.62 ≈ head-and-shoulders above the
## waterline). Deeper than neutral pushes up, shallower lets it settle; the
## result is a vertical speed clamped to ±max_speed so it bobs rather than pops.
static func buoyancy(
	submersion_fraction: float, neutral: float, strength: float, max_speed: float
) -> float:
	return clampf((submersion_fraction - neutral) * strength, -max_speed, max_speed)


## Whether the head is under: submerged at or past head_fraction (near 1.0,
## since submersion hits 1.0 as the head goes under). Below it the player can
## still breathe even while wading deep.
static func head_underwater(submersion_fraction: float, head_fraction: float) -> bool:
	return submersion_fraction >= head_fraction


## Next breath reserve in [0, 1]: underwater it drains over breath_seconds; at
## the surface it refills at recover_rate per second (faster than it drained, so
## a gasp recovers quickly). A degenerate breath_seconds is treated as instant.
static func next_oxygen(
	oxygen: float, underwater: bool, breath_seconds: float, recover_rate: float, delta: float
) -> float:
	if underwater:
		return clampf(oxygen - delta / maxf(breath_seconds, 0.0001), 0.0, 1.0)
	return clampf(oxygen + recover_rate * delta, 0.0, 1.0)
