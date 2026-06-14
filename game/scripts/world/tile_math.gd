class_name TileMath
extends RefCounted
## Pure tile-grid math for the world streamer.
##
## Static functions only, no scene access — the pattern for testable logic
## (docs/ARCHITECTURE.md): TileStreamer stays thin, the set/priority math
## lives here and is covered by tests/unit/test_tile_math.gd.
##
## World space is a square grid of tiles in the XZ plane (docs/ARCHITECTURE.md
## "Streaming design direction"). A tile coordinate is the Vector2i of its
## column (x) and row (z). Rings are square (Chebyshev distance) so the
## resident set matches the grid, not a circle.

## Extra queue weight (in metres) given to tiles straight ahead of the motion
## vector — a tile directly in the direction of travel ranks as if it were a
## full tile closer.
const LOOKAHEAD_WEIGHT: float = 128.0


## Grid coordinate of the tile containing a world position.
static func tile_coord(position: Vector3, tile_size: float) -> Vector2i:
	return Vector2i(floori(position.x / tile_size), floori(position.z / tile_size))


## World-space centre of a tile (y = 0).
static func tile_center(coord: Vector2i, tile_size: float) -> Vector3:
	return Vector3((coord.x + 0.5) * tile_size, 0.0, (coord.y + 0.5) * tile_size)


## Chebyshev (square-ring) distance between two tile coordinates.
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Every coordinate within `radius` rings of `center` — the residency target.
static func desired_set(center: Vector2i, radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			coords.append(center + Vector2i(dx, dy))
	return coords


## Coordinates from `desired` that are in neither `resident` nor `loading`.
static func missing(
	desired: Array[Vector2i], resident: Dictionary, loading: Dictionary
) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for coord in desired:
		if not resident.has(coord) and not loading.has(coord):
			coords.append(coord)
	return coords


## Queue weight for loading a tile: planar distance from the observer, minus
## a bonus for tiles aligned with the motion vector so the streamer works
## ahead of travel. Lower loads sooner.
static func load_priority(
	coord: Vector2i, tile_size: float, origin: Vector3, velocity: Vector3
) -> float:
	var center := tile_center(coord, tile_size)
	var offset := Vector3(center.x - origin.x, 0.0, center.z - origin.z)
	var distance := offset.length()
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if distance < 0.001 or planar_velocity.length() < 0.1:
		return distance
	var alignment := planar_velocity.normalized().dot(offset / distance)
	return distance - alignment * LOOKAHEAD_WEIGHT


## A copy of `coords` sorted so the highest-priority load comes first.
static func load_order(
	coords: Array[Vector2i], tile_size: float, origin: Vector3, velocity: Vector3
) -> Array[Vector2i]:
	var ordered := coords.duplicate()
	ordered.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (
				load_priority(a, tile_size, origin, velocity)
				< load_priority(b, tile_size, origin, velocity)
			)
	)
	return ordered


## Resident coordinates that have drifted outside `unload_radius` rings of
## `center`. Keeping unload_radius > load_radius gives hysteresis: a tile on
## the boundary is not unloaded the moment the observer steps back a metre.
static func stale(resident: Dictionary, center: Vector2i, unload_radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for coord: Vector2i in resident:
		if chebyshev(coord, center) > unload_radius:
			coords.append(coord)
	return coords
