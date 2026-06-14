class_name Footsteps
extends RefCounted
## Pure stride-cadence and surface classification for footstep events.
##
## Static functions only, no scene access (docs/ARCHITECTURE.md). The Player
## banks ground distance each frame and asks here when a foot has fallen and
## what it landed on; it then emits a `footstep(surface, is_left)` signal.
## Surface-typed audio listens on that signal once CC0 step samples land
## (separate M1 art task) — keeping the trigger and the sample decoupled.
## Covered by tests/unit/test_footsteps.gd.

## Surface key emitted when a collider carries no known surface group.
const DEFAULT_SURFACE: String = "concrete"

## Collider group -> surface key. Authors tag floor colliders with one of these
## groups; first match wins. World content adds entries here as materials grow.
const SURFACE_GROUPS: Dictionary = {
	"surface_grass": "grass",
	"surface_sand": "sand",
	"surface_metal": "metal",
	"surface_wood": "wood",
	"surface_water": "water",
}


## Stride length (m per footfall) for the current speed: it stretches from
## walk_stride toward run_stride as speed climbs from walk to run, so a sprint
## lengthens the gait instead of machine-gunning steps. Speeds at/below
## walk_speed use walk_stride; at/above run_speed, run_stride.
static func stride_length(
	speed: float, walk_speed: float, run_speed: float, walk_stride: float, run_stride: float
) -> float:
	if run_speed <= walk_speed:
		return walk_stride
	var t := clampf(inverse_lerp(walk_speed, run_speed, speed), 0.0, 1.0)
	return lerpf(walk_stride, run_stride, t)


## Bank this frame's ground distance. Airborne frames add nothing (no contact),
## so the accumulator holds until the character lands again.
static func accumulate(accum: float, planar_speed: float, on_floor: bool, delta: float) -> float:
	if not on_floor:
		return accum
	return accum + planar_speed * delta


## True once the banked distance reaches a full stride. A non-positive stride
## (degenerate config) never steps, avoiding a divide-by-zero cadence.
static func should_step(accum: float, stride_len: float) -> bool:
	return stride_len > 0.0 and accum >= stride_len


## Distance left over after a footfall fires; subtracting the stride keeps the
## remainder so cadence stays even rather than resetting to zero each step.
static func consume(accum: float, stride_len: float) -> float:
	if stride_len <= 0.0:
		return accum
	return accum - stride_len


## Classify a floor collider from its group list: the first group that maps to a
## known surface wins; anything untagged reads as the default surface.
static func surface_for_groups(groups: Array) -> String:
	for group in groups:
		if SURFACE_GROUPS.has(group):
			return SURFACE_GROUPS[group]
	return DEFAULT_SURFACE
