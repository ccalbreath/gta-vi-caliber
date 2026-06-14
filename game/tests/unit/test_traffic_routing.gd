extends RefCounted
## Unit tests for TrafficRouting — the road-graph follower that keeps ambient
## cars on real streets, in the right lane.


func _grid() -> RoadNetwork:
	var net := RoadNetwork.new(1.0)
	# A connected lattice: three E-W streets and three N-S streets, 40 m apart.
	for z in [0.0, 40.0, 80.0]:
		net.add_polyline(
			PackedVector3Array([Vector3(0, 0, z), Vector3(40, 0, z), Vector3(80, 0, z)])
		)
	for x in [0.0, 40.0, 80.0]:
		net.add_polyline(
			PackedVector3Array([Vector3(x, 0, 0), Vector3(x, 0, 40), Vector3(x, 0, 80)])
		)
	net.build_spatial_index()
	return net


func _route_length(pts: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


func test_right_of_north_is_east() -> bool:
	# Driving north (-Z), the right lane is east (+X) — right-hand traffic.
	return TrafficRouting.right_of(Vector3(0, 0, -1)).is_equal_approx(Vector3(1, 0, 0))


func test_right_of_east_is_south() -> bool:
	return TrafficRouting.right_of(Vector3(1, 0, 0)).is_equal_approx(Vector3(0, 0, 1))


func test_route_reaches_min_length() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var pts := TrafficRouting.route_points(
		_grid(), Vector3(5, 0, 0), Vector3(1, 0, 0), 120.0, rng, 2.0
	)
	# The walk traverses >= 120 m of road; the emitted waypoints span that minus
	# the partial entry segment and a little corner shortening from the lane offset.
	return pts.size() >= 3 and _route_length(pts) >= 70.0


func test_route_waypoints_hug_the_streets() -> bool:
	var net := _grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var pts := TrafficRouting.route_points(net, Vector3(5, 0, 0), Vector3(1, 0, 0), 100.0, rng, 2.0)
	# Each waypoint sits within (lane offset + tolerance) of a real road point.
	for p in pts:
		if float(net.nearest_point(p)["dist"]) > 2.5:
			return false
	return pts.size() >= 2


func test_route_does_not_immediately_reverse() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Heading east from near the origin: the first hop must go forward (east),
	# never jump back west of the start.
	var pts := TrafficRouting.route_points(
		_grid(), Vector3(5, 0, 0), Vector3(1, 0, 0), 60.0, rng, 0.0
	)
	return pts.size() >= 2 and pts[0].x >= 5.0 - 0.001


func test_route_empty_on_blank_network() -> bool:
	var rng := RandomNumberGenerator.new()
	var net := RoadNetwork.new(1.0)
	return (
		TrafficRouting.route_points(net, Vector3.ZERO, Vector3(1, 0, 0), 50.0, rng, 2.0).size() == 0
	)
