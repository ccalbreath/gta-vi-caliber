extends RefCounted
## Unit tests for MapProjection — minimap coordinate math. Centre, scale,
## rotation and edge-clamping all have to be exact or blips drift off the disc.


func test_center_maps_to_origin() -> bool:
	var c := Vector3(100, 0, 50)
	return MapProjection.world_to_map(c, c, 2.0).is_equal_approx(Vector2.ZERO)


func test_east_is_right_south_is_down() -> bool:
	var c := Vector3.ZERO
	var east := MapProjection.world_to_map(Vector3(10, 0, 0), c, 1.0)
	var south := MapProjection.world_to_map(Vector3(0, 0, 10), c, 1.0)
	return east.is_equal_approx(Vector2(10, 0)) and south.is_equal_approx(Vector2(0, 10))


func test_zoom_scales() -> bool:
	var c := Vector3.ZERO
	var near := MapProjection.world_to_map(Vector3(20, 0, 0), c, 1.0)
	var far := MapProjection.world_to_map(Vector3(20, 0, 0), c, 2.0)  # 2 m/px -> half pixels
	return near.x == 20.0 and far.x == 10.0


func test_rotation_spins_the_map() -> bool:
	# A point due east, rotated +90°, lands on +y (down).
	var p := MapProjection.world_to_map(Vector3(10, 0, 0), Vector3.ZERO, 1.0, PI / 2.0)
	return p.is_equal_approx(Vector2(0, 10))


func test_is_within_disc() -> bool:
	return (
		MapProjection.is_within(Vector2(3, 4), 5.0)
		and not MapProjection.is_within(Vector2(9, 0), 5.0)
	)


func test_clamp_passes_inside_blips() -> bool:
	var p := Vector2(2, 1)
	return MapProjection.clamp_to_ring(p, 5.0) == p


func test_clamp_pins_outside_blips_to_rim() -> bool:
	var clamped := MapProjection.clamp_to_ring(Vector2(100, 0), 8.0)
	return absf(clamped.length() - 8.0) < 0.001 and clamped.x > 0.0


func test_fit_uses_the_tighter_axis() -> bool:
	# 200×100 m into a 400×400 px view: 0.5 vs 0.25 m/px -> take 0.5 so it fits.
	return (
		absf(MapProjection.fit_meters_per_pixel(Vector2(200, 100), Vector2(400, 400)) - 0.5) < 0.001
	)


func test_fit_accounts_for_margin() -> bool:
	# 360 px avail after 20 px margins each side; 360 m wide -> 1.0 m/px.
	return (
		absf(MapProjection.fit_meters_per_pixel(Vector2(360, 10), Vector2(400, 400), 20.0) - 1.0)
		< 0.001
	)
