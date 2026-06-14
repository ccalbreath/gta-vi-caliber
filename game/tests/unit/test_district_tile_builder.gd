class_name TestDistrictTileBuilder
extends GdUnitTestSuite
## Thread-side district preparation stays scene-free and deterministic.

const TILE_SIZE: float = 128.0
const MIAMI_SCENE := preload("res://scenes/world/miami.tscn")


func test_partitions_real_geometry_into_128_m_tiles() -> void:
	var plan := DistrictTileBuilder.build(_district_data(), TILE_SIZE)
	var chunks: Array = plan["chunks"]
	var building_total := 0
	var road_total := 0
	for chunk: Dictionary in chunks:
		building_total += (chunk["buildings"] as Array).size()
		road_total += (chunk["roads"] as Array).size()
	assert_int(chunks.size()).is_greater_equal(2)
	assert_int(building_total).is_equal(2)
	assert_int(road_total).is_equal(1)
	assert_int(int(plan["building_count"])).is_equal(2)
	assert_int(int(plan["road_count"])).is_equal(1)


func test_hlod_uses_simpler_building_silhouettes() -> void:
	var plan := DistrictTileBuilder.build(_district_data(), TILE_SIZE)
	var compared := false
	for chunk: Dictionary in plan["chunks"]:
		var detailed: PackedVector3Array = chunk["buildings_geo"]["vertices"]
		var hlod: PackedVector3Array = chunk["hlod_geo"]["vertices"]
		if detailed.is_empty():
			continue
		assert_bool(hlod.is_empty()).is_false()
		assert_int(hlod.size()).is_less_equal(detailed.size())
		compared = true
		break
	assert_bool(compared).is_true()


func test_prepares_render_navigation_and_facade_inputs() -> void:
	var plan := DistrictTileBuilder.build(_district_data(), TILE_SIZE)
	var has_buildings := false
	var has_roads := false
	var has_sidewalks := false
	var has_collision := false
	var has_navigation := false
	var has_rooftops := false
	for chunk: Dictionary in plan["chunks"]:
		has_buildings = (
			has_buildings
			or not (chunk["buildings_geo"]["vertices"] as PackedVector3Array).is_empty()
		)
		has_roads = (
			has_roads or not (chunk["roads_geo"]["vertices"] as PackedVector3Array).is_empty()
		)
		has_sidewalks = (
			has_sidewalks
			or not (chunk["sidewalks_geo"]["vertices"] as PackedVector3Array).is_empty()
		)
		has_collision = (has_collision or not (chunk["collision_face_batches"] as Array).is_empty())
		has_navigation = (
			has_navigation or not (chunk["navigation_vertices"] as PackedVector3Array).is_empty()
		)
		has_rooftops = (has_rooftops or not (chunk["rooftop_ac"] as Array[Transform3D]).is_empty())
	assert_bool(has_buildings).is_true()
	assert_bool(has_roads).is_true()
	assert_bool(has_sidewalks).is_true()
	assert_bool(has_collision).is_true()
	assert_bool(has_navigation).is_true()
	assert_bool(has_rooftops).is_true()


func test_collision_commit_attaches_one_convex_building_per_step() -> void:
	var district := _district_data()
	var parent := Node3D.new()
	var commit := DistrictCollisionCommit.new(
		district["buildings"], GeoProjection.new(25.0, -80.0)
	)
	assert_bool(commit.step(parent)).is_false()
	var body := parent.get_node("Collision") as StaticBody3D
	assert_int(body.collision_layer).is_equal(BuildingCollision.WORLD_LAYER)
	assert_bool(body.is_in_group("world_buildings")).is_true()
	assert_int(body.get_child_count()).is_equal(1)
	var collision := body.get_child(0) as CollisionShape3D
	assert_bool(collision.shape is ConvexPolygonShape3D).is_true()
	assert_bool(commit.step(parent)).is_true()
	assert_int(body.get_child_count()).is_equal(2)
	parent.free()


func test_load_order_looks_ahead_of_motion() -> void:
	var districts := [
		{"name": "behind", "offset": Vector2(-500, 0)},
		{"name": "ahead", "offset": Vector2(500, 0)},
	]
	var result := Streaming.resolve(Vector2.ZERO, districts, 1500.0, 2200.0, {}, Vector2(20.0, 0.0))
	assert_array(result["to_load"]).is_equal(["ahead", "behind"])


func test_navigation_commit_spreads_polygon_attachment_across_steps() -> void:
	var vertices := PackedVector3Array()
	var polygons: Array[PackedInt32Array] = []
	for index in DistrictNavigationCommit.POLYGONS_PER_STEP + 1:
		var offset := float(index) * 2.0
		var vertex_index := vertices.size()
		(
			vertices
			. append_array(
				PackedVector3Array(
					[
						Vector3(offset, 0.0, 0.0),
						Vector3(offset + 1.0, 0.0, 0.0),
						Vector3(offset, 0.0, 1.0),
					]
				)
			)
		)
		polygons.append(PackedInt32Array([vertex_index, vertex_index + 1, vertex_index + 2]))
	var parent := Node3D.new()
	var commit := DistrictNavigationCommit.new(vertices, polygons)
	assert_bool(commit.step(parent)).is_false()
	assert_int(parent.get_child_count()).is_equal(0)
	assert_bool(commit.step(parent)).is_true()
	assert_int(parent.get_child_count()).is_equal(1)
	parent.free()


func test_miami_uses_measured_district_residency_radii() -> void:
	var scene := MIAMI_SCENE.instantiate()
	var streamer := scene.get_node("Streamer")
	assert_float(float(streamer.get("load_radius"))).is_equal_approx(1600.0, 0.01)
	assert_float(float(streamer.get("unload_radius"))).is_equal_approx(2400.0, 0.01)
	scene.free()


func _district_data() -> Dictionary:
	return {
		"name": "test_district",
		"origin": {"lat": 25.0, "lon": -80.0},
		"centroid": {"lat": 25.0, "lon": -79.999},
		"buildings":
		[
			{
				"id": 1,
				"height_m": 24.0,
				"footprint":
				[
					[25.0000, -80.0000],
					[25.0000, -79.9998],
					[24.9999, -79.9997],
					[24.9998, -79.9998],
					[24.9998, -80.0000],
				],
			},
			{
				"id": 2,
				"height_m": 12.0,
				"footprint":
				[
					[25.0000, -79.9979],
					[25.0000, -79.9977],
					[24.9998, -79.9977],
					[24.9998, -79.9979],
				],
			},
		],
		"roads":
		[
			{
				"id": 3,
				"width_m": 10.0,
				"path": [[24.9996, -80.0002], [24.9996, -79.9975]],
			},
		],
	}
