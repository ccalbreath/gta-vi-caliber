extends RefCounted
## Unit tests for TileMath (see tests/run_tests.gd for the runner contract:
## test_* methods return true to pass).

const TILE: float = 128.0


func test_tile_coord_at_origin() -> bool:
	return TileMath.tile_coord(Vector3(1.0, 0.0, 1.0), TILE) == Vector2i.ZERO


func test_tile_coord_floors_negative_positions() -> bool:
	return TileMath.tile_coord(Vector3(-0.5, 0.0, -128.5), TILE) == Vector2i(-1, -2)


func test_tile_coord_ignores_height() -> bool:
	return TileMath.tile_coord(Vector3(200.0, 500.0, 200.0), TILE) == Vector2i(1, 1)


func test_tile_center_roundtrips_through_tile_coord() -> bool:
	var coord := Vector2i(3, -2)
	return TileMath.tile_coord(TileMath.tile_center(coord, TILE), TILE) == coord


func test_chebyshev_takes_largest_axis() -> bool:
	return TileMath.chebyshev(Vector2i.ZERO, Vector2i(2, -3)) == 3


func test_desired_set_radius_zero_is_just_center() -> bool:
	var coords := TileMath.desired_set(Vector2i(4, 4), 0)
	return coords.size() == 1 and coords[0] == Vector2i(4, 4)


func test_desired_set_radius_two_has_25_tiles() -> bool:
	return TileMath.desired_set(Vector2i.ZERO, 2).size() == 25


func test_desired_set_includes_ring_corners() -> bool:
	var coords := TileMath.desired_set(Vector2i(1, 1), 2)
	return coords.has(Vector2i(-1, -1)) and coords.has(Vector2i(3, 3))


func test_missing_excludes_resident_and_loading() -> bool:
	var desired: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var resident := {Vector2i(0, 0): null}
	var loading := {Vector2i(1, 0): "path"}
	var coords := TileMath.missing(desired, resident, loading)
	return coords.size() == 1 and coords[0] == Vector2i(2, 0)


func test_load_order_nearest_first_when_still() -> bool:
	var origin := TileMath.tile_center(Vector2i.ZERO, TILE)
	var coords: Array[Vector2i] = [Vector2i(5, 0), Vector2i(1, 0)]
	var ordered := TileMath.load_order(coords, TILE, origin, Vector3.ZERO)
	return ordered[0] == Vector2i(1, 0)


func test_load_order_prefers_tiles_ahead_of_motion() -> bool:
	# (1, 0) and (-1, 0) are equidistant; moving toward +X must rank (1, 0) first.
	var origin := TileMath.tile_center(Vector2i.ZERO, TILE)
	var coords: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0)]
	var ordered := TileMath.load_order(coords, TILE, origin, Vector3(10.0, 0.0, 0.0))
	return ordered[0] == Vector2i(1, 0)


func test_load_priority_is_distance_when_still() -> bool:
	var origin := TileMath.tile_center(Vector2i.ZERO, TILE)
	var priority := TileMath.load_priority(Vector2i(1, 0), TILE, origin, Vector3.ZERO)
	return absf(priority - TILE) < 0.0001


func test_stale_lists_tiles_outside_unload_radius() -> bool:
	var resident := {Vector2i(0, 0): null, Vector2i(4, 0): null}
	var coords := TileMath.stale(resident, Vector2i.ZERO, 3)
	return coords.size() == 1 and coords[0] == Vector2i(4, 0)


func test_stale_keeps_tiles_on_the_boundary() -> bool:
	var resident := {Vector2i(3, 3): null}
	return TileMath.stale(resident, Vector2i.ZERO, 3).is_empty()
