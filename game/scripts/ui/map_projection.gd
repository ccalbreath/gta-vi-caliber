class_name MapProjection
extends RefCounted
## World→map coordinate math for the minimap and full map (roadmap M5). Turns a
## world XZ position into a pixel offset from the map centre, scaled by zoom and
## rotated so the player's heading can point "up", with GTA-style edge-clamping
## for blips that fall outside the minimap disc.
##
## Pure and deterministic (vectors in, vectors out), so it unit-tests headless
## (tests/unit/test_map_projection.gd). The Minimap Control just feeds it the
## player position/heading and draws the results.


## World position → map-local pixels relative to centre. Map +x is right, +y is
## down (screen space); world +x is east, +z is south, so south reads as down
## before rotation. `rotation` (radians) spins the map — pass the player's yaw to
## keep their facing pointing up.
static func world_to_map(
	world: Vector3, center: Vector3, meters_per_pixel: float, rotation: float = 0.0
) -> Vector2:
	var mpp := maxf(meters_per_pixel, 0.0001)
	var p := Vector2((world.x - center.x) / mpp, (world.z - center.z) / mpp)
	return p.rotated(rotation)


## Is a map point inside the minimap disc of the given radius?
static func is_within(map_point: Vector2, radius: float) -> bool:
	return map_point.length() <= radius


## Clamp an off-disc blip to the rim (so distant objectives still show a
## direction), or pass it through unchanged when already inside.
static func clamp_to_ring(map_point: Vector2, radius: float) -> Vector2:
	if map_point.length() <= radius:
		return map_point
	return map_point.normalized() * radius


## Metres-per-pixel that fits a world area of `world_extent` (metres, XZ) into a
## `view_px` viewport with `margin_px` of padding, preserving aspect (uses the
## tighter axis). For the full-screen map's auto-zoom-to-fit.
static func fit_meters_per_pixel(
	world_extent: Vector2, view_px: Vector2, margin_px: float = 0.0
) -> float:
	var avail := Vector2(
		maxf(view_px.x - 2.0 * margin_px, 1.0), maxf(view_px.y - 2.0 * margin_px, 1.0)
	)
	return maxf(maxf(world_extent.x / avail.x, world_extent.y / avail.y), 0.0001)
