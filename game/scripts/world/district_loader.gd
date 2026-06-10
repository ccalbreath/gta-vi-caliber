extends Node3D
## Builds a real-world city district from a normalized OSM data file
## (produced by tools/osm/fetch_district.py). Reads building footprints and road
## polylines, projects them into local metres via GeoProjection, and assembles
## batched meshes via CityBuilder. All heavy geometry math lives in those tested
## helpers; this node only orchestrates scene assembly.
##
## Buildings merge into one MeshInstance3D + one trimesh collider so the player
## and vehicles collide with the skyline; roads merge into a single flat,
## collision-free ribbon mesh laid just above the ground plane.

signal district_built(building_count: int, road_count: int)

## res:// path to the district JSON (OSM-derived, ODbL).
@export_file("*.json") var district_path: String = "res://assets/world/downtown_la.json"
## Build collision for buildings. Off speeds up pure-visual previews.
@export var build_collision: bool = true
## Spawn a ground tile sized to this district's bounds (so a district drops into
## a multi-district world without a hand-placed plane under it).
@export var spawn_ground: bool = true
## Move the player + spawn marker onto this district's nearest street. In a
## multi-district scene only ONE loader should own the player.
@export var place_player: bool = true
## Extra ground beyond the district footprint, in metres.
@export var ground_margin: float = 90.0

var _building_mat: StandardMaterial3D
var _roof_mat: StandardMaterial3D
var _road_mat: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	var data := _load_district(district_path)
	if data.is_empty():
		push_error("district_loader: could not load %s" % district_path)
		return

	var origin: Dictionary = data["origin"]
	var proj := GeoProjection.new(origin["lat"], origin["lon"])

	if spawn_ground:
		_build_ground(data, proj)
	var built_buildings := _build_buildings(data.get("buildings", []), proj)
	_build_roads(data.get("roads", []), proj)
	if place_player:
		var centre_geo: Dictionary = data.get("centroid", origin)
		var centre := proj.to_local(centre_geo["lat"], centre_geo["lon"])
		_place_actors_on_street(data.get("roads", []), proj, centre)

	var nb: int = (data.get("buildings", []) as Array).size()
	var nr: int = (data.get("roads", []) as Array).size()
	print(
		(
			"district_loader: built %s — %d buildings (%d meshed), %d roads"
			% [data.get("name", "district"), nb, built_buildings, nr]
		)
	)
	district_built.emit(nb, nr)


func _load_district(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Merge a geometry dict into accumulator arrays, offsetting indices.
static func _append_geo(
	verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array, geo: Dictionary
) -> void:
	if geo.is_empty():
		return
	var offset := verts.size()
	verts.append_array(geo["vertices"])
	norms.append_array(geo["normals"])
	for i in geo["indices"] as PackedInt32Array:
		idx.append(offset + i)


func _project_ring(raw: Array, proj: GeoProjection) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for pair in raw:
		ring.append(proj.to_local_2d(pair[0], pair[1]))
	return ring


func _build_buildings(buildings: Array, proj: GeoProjection) -> int:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var meshed := 0

	for b in buildings:
		var ring := _project_ring(b["footprint"], proj)
		var geo := CityBuilder.extrude_prism(ring, 0.0, float(b["height_m"]))
		if geo.is_empty():
			continue
		_append_geo(verts, norms, idx, geo)
		meshed += 1

	if verts.is_empty():
		return 0

	var mesh := CityBuilder.arrays_to_mesh({"vertices": verts, "normals": norms, "indices": idx})
	mesh.surface_set_material(0, _building_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Buildings"
	mi.mesh = mesh
	add_child(mi)
	if build_collision:
		mi.create_trimesh_collision()
	return meshed


func _build_roads(roads: Array, proj: GeoProjection) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()

	for r in roads:
		var path := _project_ring(r["path"], proj)
		var geo := CityBuilder.road_ribbon(path, float(r["width_m"]), 0.05)
		_append_geo(verts, norms, idx, geo)

	if verts.is_empty():
		return
	var mesh := CityBuilder.arrays_to_mesh({"vertices": verts, "normals": norms, "indices": idx})
	mesh.surface_set_material(0, _road_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Roads"
	mi.mesh = mesh
	add_child(mi)


## Spawn a flat ground tile covering the district's projected footprint so the
## player and vehicles have something to stand on, wherever the district sits in
## the shared world.
func _build_ground(data: Dictionary, proj: GeoProjection) -> void:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for collection in [data.get("buildings", []), data.get("roads", [])]:
		for item in collection:
			var pts: Array = item.get("footprint", item.get("path", []))
			for pair in pts:
				var p := proj.to_local(pair[0], pair[1])
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_z = minf(min_z, p.z)
				max_z = maxf(max_z, p.z)
	if min_x == INF:
		return

	var size_x := (max_x - min_x) + ground_margin * 2.0
	var size_z := (max_z - min_z) + ground_margin * 2.0
	var centre := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.28, 0.3)
	mat.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size_x, size_z)
	plane.material = mat

	var body := StaticBody3D.new()
	body.name = "Ground"
	body.position = centre
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size_x, 1.0, size_z)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)


## Move the player + spawn marker onto the road vertex nearest this district's
## centre so the player never starts trapped inside a building footprint.
func _place_actors_on_street(roads: Array, proj: GeoProjection, centre: Vector3) -> void:
	var best := centre
	var best_dist := INF
	for r in roads:
		for pair in r["path"]:
			var p := proj.to_local(pair[0], pair[1])
			var d := p.distance_to(centre)
			if d < best_dist:
				best_dist = d
				best = p
	best.y = 1.0

	var tree := get_tree()
	if tree == null:
		return
	for marker in tree.get_nodes_in_group("spawn_points"):
		if marker is Node3D:
			(marker as Node3D).global_position = best
	for player in tree.get_nodes_in_group("player"):
		if player is Node3D:
			(player as Node3D).global_position = best + Vector3(0, 0.5, 0)


func _make_materials() -> void:
	_building_mat = StandardMaterial3D.new()
	_building_mat.albedo_color = Color(0.62, 0.63, 0.66)
	_building_mat.roughness = 0.85
	_building_mat.metallic = 0.0
	# Double-sided keeps interiors lit if a footprint winds oddly.
	_building_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_roof_mat = StandardMaterial3D.new()
	_roof_mat.albedo_color = Color(0.4, 0.41, 0.45)
	_roof_mat.roughness = 0.95

	_road_mat = StandardMaterial3D.new()
	_road_mat.albedo_color = Color(0.16, 0.16, 0.19)
	_road_mat.roughness = 1.0
