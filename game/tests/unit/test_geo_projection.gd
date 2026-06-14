extends RefCounted
## Unit tests for GeoProjection. Validates the real-world → local-metre mapping
## that the whole city geometry is built on: get this wrong and every building
## lands in the wrong place.


func test_origin_maps_to_zero() -> bool:
	var proj := GeoProjection.new(34.05, -118.25)
	var p := proj.to_local(34.05, -118.25)
	return p.length() < 0.001


func test_one_degree_latitude_is_111km_north() -> bool:
	var proj := GeoProjection.new(0.0, 0.0)
	# One degree north of the equator origin → -Z (north), ~111.32 km.
	var p := proj.to_local(1.0, 0.0)
	var ok_axis := absf(p.x) < 0.001 and absf(p.y) < 0.001
	var ok_dist := absf(-p.z - GeoProjection.METRES_PER_DEG_LAT) < 1.0
	return ok_axis and ok_dist


func test_longitude_shrinks_with_latitude() -> bool:
	# A degree of longitude is ~111 km at the equator but only ~91 km at LA's
	# latitude (cos 34° ≈ 0.829). East is +X.
	var proj := GeoProjection.new(34.05, -118.25)
	var p := proj.to_local(34.05, -118.25 + 1.0)
	var expected := GeoProjection.METRES_PER_DEG_LAT * cos(deg_to_rad(34.05))
	return p.z == 0.0 and absf(p.x - expected) < 1.0 and p.x < GeoProjection.METRES_PER_DEG_LAT


func test_east_is_positive_x_north_is_negative_z() -> bool:
	var proj := GeoProjection.new(34.05, -118.25)
	var north := proj.to_local(34.06, -118.25)
	var east := proj.to_local(34.05, -118.24)
	return north.z < 0.0 and absf(north.x) < 0.001 and east.x > 0.0 and absf(east.z) < 0.001


func test_inverse_round_trips() -> bool:
	var proj := GeoProjection.new(34.0503, -118.2523)
	var geo := Vector2(34.0541, -118.2487)
	var local := proj.to_local(geo.x, geo.y)
	var back := proj.to_geo(local)
	return absf(back.x - geo.x) < 1e-6 and absf(back.y - geo.y) < 1e-6


func test_to_local_2d_matches_3d() -> bool:
	var proj := GeoProjection.new(34.05, -118.25)
	var p3 := proj.to_local(34.0541, -118.2487)
	var p2 := proj.to_local_2d(34.0541, -118.2487)
	return absf(p2.x - p3.x) < 0.001 and absf(p2.y - p3.z) < 0.001
