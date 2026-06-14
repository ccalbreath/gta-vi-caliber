extends RefCounted
## Runtime-shape checks for the original Florida backdrop builder.


func test_backdrop_builds_named_premium_layers() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var ok := (
		backdrop.has_node("StateOcean")
		and backdrop.has_node("StateLandmass")
		and backdrop.has_node("SandCoastline")
		and backdrop.has_node("SouthBeachSurf")
		and backdrop.has_node("StateCauseways")
		and backdrop.has_node("SignatureBridges")
		and backdrop.has_node("OriginalRouteDetails")
		and backdrop.has_node("OriginalMarinas")
		and backdrop.has_node("OriginalBeachResorts")
		and backdrop.has_node("OriginalLandmarks")
		and backdrop.has_node("ThreeJsFloridaModels")
		and backdrop.has_node("ThreeJsFloridaCityBlocks")
		and backdrop.has_node("ThreeJsFloridaNeonDetails")
		and backdrop.has_node("ThreeJsFloridaRegionalDestinations")
		and backdrop.has_node("ThreeJsFloridaInfrastructureDetails")
		and backdrop.has_node("ThreeJsFloridaEnvironmentDetails")
		and backdrop.has_node("ThreeJsFloridaTrafficMarineDetails")
		and backdrop.has_node("ThreeJsFloridaVistaDetails")
		and backdrop.has_node("ThreeJsFloridaStreetlifeDetails")
		and backdrop.has_node("OriginalCityAnchors")
		and backdrop.has_node("OriginalMapMarkers")
		and backdrop.has_node("WetlandCypressTrunks")
		and backdrop.has_node("WetlandCypressCrowns")
		and backdrop.has_node("StateOceanSwimVolume")
	)
	backdrop.free()
	return ok


func test_backdrop_builds_all_authored_city_labels() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var anchors := backdrop.get_node("OriginalCityAnchors")
	var found := 0
	for city in FloridaMapModel.city_nodes(backdrop.map_scale):
		var label_name := "%sLabel" % String(city["name"]).replace(" ", "")
		if anchors.has_node(label_name):
			found += 1
	backdrop.free()
	return found == FloridaMapModel.CITY_NODES.size()


func test_backdrop_builds_all_authored_landmarks() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var landmarks := backdrop.get_node("OriginalLandmarks")
	var required := ["TorchKeyLight", "SunsetWheel", "AtlasPointLaunch", "GulfGateArch"]
	for node_name in required:
		if not landmarks.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_builds_threejs_model_pack_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaModels")
	var required := ["ThreeJsMiamiResortPack", "ThreeJsKeysResortPack", "ThreeJsGulfRoutePack"]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_model_pack_contains_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaModels")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 60


func test_backdrop_builds_threejs_city_block_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaCityBlocks")
	var required := [
		"ThreeJsBrickellCityBlock",
		"ThreeJsBeachCityBlock",
		"ThreeJsGulfCityBlock",
		"ThreeJsNorthCoastCityBlock"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_city_blocks_contain_dense_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaCityBlocks")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 300


func test_backdrop_builds_threejs_neon_detail_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaNeonDetails")
	var required := [
		"ThreeJsBeachNeonDetail",
		"ThreeJsBrickellNeonDetail",
		"ThreeJsKeysNeonDetail",
		"ThreeJsGulfNeonDetail"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_neon_details_have_lights_and_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaNeonDetails")
	var mesh_count := 0
	var light_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
		light_count += _count_lights(child)
	backdrop.free()
	return mesh_count >= 150 and light_count == 16


func test_backdrop_builds_threejs_regional_destination_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaRegionalDestinations")
	var required := [
		"ThreeJsPanhandleRegionalPack",
		"ThreeJsSpaceCoastRegionalPack",
		"ThreeJsWetlandRegionalPack",
		"ThreeJsKeysRegionalPack",
		"ThreeJsGulfRegionalPack"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_regional_destinations_contain_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaRegionalDestinations")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 450


func test_backdrop_builds_threejs_infrastructure_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaInfrastructureDetails")
	var required := [
		"ThreeJsTurnpikeInfrastructure",
		"ThreeJsWetlandInfrastructure",
		"ThreeJsKeysInfrastructure",
		"ThreeJsBeachInfrastructure",
		"ThreeJsPanhandleInfrastructure",
		"ThreeJsGulfInfrastructure"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_infrastructure_details_contain_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaInfrastructureDetails")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 650


func test_backdrop_builds_threejs_environment_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaEnvironmentDetails")
	var required := [
		"ThreeJsBeachEnvironment",
		"ThreeJsWetlandEnvironment",
		"ThreeJsKeysEnvironment",
		"ThreeJsGulfEnvironment",
		"ThreeJsNorthCoastEnvironment",
		"ThreeJsCityEdgeEnvironment"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_environment_details_contain_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaEnvironmentDetails")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 900


func test_backdrop_builds_threejs_traffic_marine_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaTrafficMarineDetails")
	var required := [
		"ThreeJsBeachTrafficMarine",
		"ThreeJsMarinaTrafficMarine",
		"ThreeJsKeysTrafficMarine",
		"ThreeJsGulfTrafficMarine",
		"ThreeJsNorthTrafficMarine",
		"ThreeJsTurnpikeTrafficMarine"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_traffic_marine_details_contain_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaTrafficMarineDetails")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 850


func test_backdrop_builds_threejs_vista_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaVistaDetails")
	var required := [
		"ThreeJsBeachVista",
		"ThreeJsKeysVista",
		"ThreeJsGulfVista",
		"ThreeJsPanhandleVista",
		"ThreeJsSpaceCoastVista",
		"ThreeJsCityVista"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_vista_details_contain_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaVistaDetails")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 650


func test_backdrop_builds_threejs_streetlife_instances() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaStreetlifeDetails")
	var required := [
		"ThreeJsBeachStreetlife",
		"ThreeJsBrickellStreetlife",
		"ThreeJsKeysStreetlife",
		"ThreeJsGulfStreetlife",
		"ThreeJsNorthStreetlife",
		"ThreeJsSpaceCoastStreetlife"
	]
	for node_name in required:
		if not models.has_node(node_name):
			backdrop.free()
			return false
	backdrop.free()
	return true


func test_backdrop_threejs_streetlife_details_contain_meshes() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var models := backdrop.get_node("ThreeJsFloridaStreetlifeDetails")
	var mesh_count := 0
	for child in models.get_children():
		mesh_count += _count_mesh_instances(child)
	backdrop.free()
	return mesh_count >= 1000


func _count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _count_lights(node: Node) -> int:
	var count := 1 if node is OmniLight3D else 0
	for child in node.get_children():
		count += _count_lights(child)
	return count


func test_backdrop_builds_key_hotels() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var resorts := backdrop.get_node("OriginalBeachResorts")
	var hotels := 0
	for child in resorts.get_children():
		if String(child.name).begins_with("KeyHotel"):
			hotels += 1
	backdrop.free()
	return hotels >= FloridaMapModel.KEY_ISLANDS.size()


func test_backdrop_builds_route_details() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var details := backdrop.get_node("OriginalRouteDetails")
	var billboards := 0
	var signs := 0
	var lights := 0
	for child in details.get_children():
		var node_name := String(child.name)
		if node_name.begins_with("RouteBillboard"):
			billboards += 1
		elif node_name.begins_with("RouteSign"):
			signs += 1
		elif node_name.begins_with("RouteLightMast"):
			lights += 1
	backdrop.free()
	return billboards > 0 and signs > 0 and lights > 0


func test_backdrop_builds_poi_marker_groups() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var markers := backdrop.get_node("OriginalMapMarkers")
	var counts := {"city": 0, "landmark": 0, "marina": 0, "route": 0}
	for child in markers.get_children():
		for kind in counts.keys():
			if child.is_in_group("poi_%s" % kind):
				counts[kind] += 1
	backdrop.free()
	return (
		counts["city"] == FloridaMapModel.CITY_NODES.size()
		and counts["landmark"] == FloridaMapModel.LANDMARKS.size()
		and counts["marina"] == FloridaMapModel.MARINAS.size()
		and counts["route"] > 0
	)


func test_backdrop_poi_markers_have_map_labels() -> bool:
	var backdrop := FloridaBackdrop.new()
	backdrop._ready()
	var markers := backdrop.get_node("OriginalMapMarkers")
	for child in markers.get_children():
		if child is Marker3D and not child.has_meta("map_label"):
			backdrop.free()
			return false
	backdrop.free()
	return true
