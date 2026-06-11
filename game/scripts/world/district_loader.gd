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

## Streetlight pole every ~this many metres of road, capped scene-wide and
## kept near the district origin (where the player spawns) so the cap is not
## eaten by far-away roads.
const STREETLIGHT_SPACING_M: float = 45.0
const MAX_STREETLIGHTS: int = 60
const STREETLIGHT_RADIUS_M: float = 250.0

## res:// path to the district JSON (OSM-derived, ODbL).
@export_file("*.json") var district_path: String = "res://assets/world/downtown_la.json"
## Build collision for buildings. Off speeds up pure-visual previews.
@export var build_collision: bool = true
## Spawn streetlight poles along roads (toggled at night by TimeOfDay).
@export var build_streetlights: bool = true

var _building_mat: Material
var _roof_mat: StandardMaterial3D
var _road_mat: Material


func _ready() -> void:
	# TimeOfDay fades our building-window glow through set_night_amount().
	add_to_group("night_emissive")
	_make_materials()
	var data := _load_district(district_path)
	if data.is_empty():
		push_error("district_loader: could not load %s" % district_path)
		return

	var origin: Dictionary = data["origin"]
	var proj := GeoProjection.new(origin["lat"], origin["lon"])

	var built_buildings := _build_buildings(data.get("buildings", []), proj)
	_build_rooftops(data.get("buildings", []), proj)
	_build_roads(data.get("roads", []), proj)
	if build_streetlights:
		_build_streetlights(data.get("roads", []), proj)
	_build_trees(data.get("roads", []), proj)
	_build_street_furniture(data.get("roads", []), proj)
	_place_actors_on_street(data.get("roads", []), proj)

	var nb: int = (data.get("buildings", []) as Array).size()
	var nr: int = (data.get("roads", []) as Array).size()
	print(
		(
			"district_loader: built %s — %d buildings (%d meshed), %d roads"
			% [data.get("name", "district"), nb, built_buildings, nr]
		)
	)
	district_built.emit(nb, nr)


## Break up the flat-topped skyline: put a water tank and an AC unit on the roof
## of each taller building (centroid of its footprint, at roof height). Shared
## meshes/materials and a cap keep the whole skyline cheap.
func _build_rooftops(buildings: Array, proj: GeoProjection) -> void:
	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.4, 0.36, 0.3)
	tank_mat.roughness = 0.85
	var ac_mat := StandardMaterial3D.new()
	ac_mat.albedo_color = Color(0.5, 0.51, 0.54)
	ac_mat.metallic = 0.5
	ac_mat.roughness = 0.5
	var tank_mesh := CylinderMesh.new()
	tank_mesh.top_radius = 1.1
	tank_mesh.bottom_radius = 1.1
	tank_mesh.height = 2.2
	var ac_mesh := BoxMesh.new()
	ac_mesh.size = Vector3(2.6, 1.2, 2.0)

	var container := Node3D.new()
	container.name = "Rooftops"
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	for b in buildings:
		if placed >= 160:
			break
		var height := float(b.get("height_m", 0.0))
		if height < 15.0:
			continue
		var ring := _project_ring(b["footprint"], proj)
		if ring.size() < 3:
			continue
		var centre := Vector2.ZERO
		for p in ring:
			centre += p
		centre /= float(ring.size())
		var roof := Node3D.new()
		roof.position = Vector3(centre.x, height, centre.y)
		var tank := MeshInstance3D.new()
		tank.mesh = tank_mesh
		tank.material_override = tank_mat
		tank.position = Vector3(rng.randf_range(-2.5, 2.5), 1.1, rng.randf_range(-2.5, 2.5))
		roof.add_child(tank)
		var ac := MeshInstance3D.new()
		ac.mesh = ac_mesh
		ac.material_override = ac_mat
		ac.position = Vector3(rng.randf_range(-2.5, 2.5), 0.6, rng.randf_range(-2.5, 2.5))
		ac.rotation.y = rng.randf() * TAU
		roof.add_child(ac)
		container.add_child(roof)
		placed += 1


## Sprinkle sidewalk furniture — trash bins and fire hydrants — along the kerb of
## the wider roads. Orientation-free props (rotationally symmetric), so no road
## tangent is needed; shared meshes/materials and a hard cap keep it cheap.
func _build_street_furniture(roads: Array, proj: GeoProjection) -> void:
	var bin_mat := StandardMaterial3D.new()
	bin_mat.albedo_color = Color(0.16, 0.28, 0.2)
	bin_mat.metallic = 0.3
	bin_mat.roughness = 0.6
	var hydrant_mat := StandardMaterial3D.new()
	hydrant_mat.albedo_color = Color(0.7, 0.13, 0.1)
	hydrant_mat.roughness = 0.5
	var bin_mesh := CylinderMesh.new()
	bin_mesh.top_radius = 0.2
	bin_mesh.bottom_radius = 0.22
	bin_mesh.height = 0.66
	var hydrant_mesh := CylinderMesh.new()
	hydrant_mesh.top_radius = 0.11
	hydrant_mesh.bottom_radius = 0.12
	hydrant_mesh.height = 0.42
	var hydrant_cap := SphereMesh.new()
	hydrant_cap.radius = 0.12
	hydrant_cap.height = 0.18

	var container := Node3D.new()
	container.name = "StreetFurniture"
	add_child(container)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var placed := 0
	for r in roads:
		if placed >= 70:
			break
		if float(r.get("width_m", 0.0)) < 8.0:
			continue
		var path := _project_ring(r["path"], proj)
		for p in StreetLight.sample_along(path, 38.0, float(r["width_m"]) * 0.5 + 1.5):
			if placed >= 70:
				break
			var prop := Node3D.new()
			prop.position = Vector3(p.x, 0.0, p.y)
			if rng.randf() < 0.5:
				_add_mesh(prop, bin_mesh, Vector3(0.0, 0.33, 0.0), bin_mat)
			else:
				_add_mesh(prop, hydrant_mesh, Vector3(0.0, 0.21, 0.0), hydrant_mat)
				_add_mesh(prop, hydrant_cap, Vector3(0.0, 0.42, 0.0), hydrant_mat)
			container.add_child(prop)
			placed += 1


func _add_mesh(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## Scatter street trees on the setback behind the kerb of the wider roads, with
## per-tree scale and yaw variety. Shares one trunk + one canopy mesh across all
## trees and caps the count, so a whole green avenue costs almost nothing.
func _build_trees(roads: Array, proj: GeoProjection) -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.32, 0.23, 0.16)
	bark.roughness = 0.95
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.21, 0.42, 0.18)
	leaf.roughness = 0.9
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trunk_mesh := TreeMesh.to_mesh(TreeMesh.trunk())
	var canopy_mesh := TreeMesh.to_mesh(TreeMesh.canopy())

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var container := Node3D.new()
	container.name = "Trees"
	add_child(container)

	var placed := 0
	for r in roads:
		if placed >= 120:
			break
		if float(r.get("width_m", 0.0)) < 9.0:
			continue
		var path := _project_ring(r["path"], proj)
		for p in StreetLight.sample_along(path, 26.0, float(r["width_m"]) * 0.5 + 2.6):
			if placed >= 120:
				break
			var tree := Node3D.new()
			tree.position = Vector3(p.x, 0.0, p.y)
			var scale_factor := rng.randf_range(0.8, 1.25)
			tree.scale = Vector3(scale_factor, scale_factor, scale_factor)
			tree.rotation.y = rng.randf() * TAU
			var trunk := MeshInstance3D.new()
			trunk.mesh = trunk_mesh
			trunk.material_override = bark
			tree.add_child(trunk)
			var crown := MeshInstance3D.new()
			crown.mesh = canopy_mesh
			crown.material_override = leaf
			crown.position = Vector3(0.0, 3.9, 0.0)
			tree.add_child(crown)
			container.add_child(tree)
			placed += 1


## Drop emissive lamp posts along the major roads (kerb side, ~42 m apart). They
## glow day and night and turn the dark city into a field of streetlights. Shared
## meshes/materials and a hard cap keep it cheap; the posts are visual only.
func _build_streetlights(roads: Array, proj: GeoProjection) -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.1, 0.1, 0.12)
	pole_mat.metallic = 0.6
	pole_mat.roughness = 0.5
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.92, 0.72)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.55)
	lamp_mat.emission_energy_multiplier = 2.5
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.14, 5.0, 0.14)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.22, 0.32)

	var container := Node3D.new()
	container.name = "StreetLights"
	add_child(container)
	# All lamp heads share lamp_mat, so one switch fades them all with day/night.
	var switch := StreetlightSwitch.new()
	switch.setup(lamp_mat, lamp_mat.emission_energy_multiplier)
	container.add_child(switch)

	var placed := 0
	for r in roads:
		if placed >= 180:
			break
		if float(r.get("width_m", 0.0)) < 8.0:
			continue
		var path := _project_ring(r["path"], proj)
		for p in StreetLight.sample_along(path, 42.0, float(r["width_m"]) * 0.5 + 1.2):
			if placed >= 180:
				break
			var lamp := Node3D.new()
			lamp.position = Vector3(p.x, 0.0, p.y)
			var pole := MeshInstance3D.new()
			pole.mesh = pole_mesh
			pole.material_override = pole_mat
			pole.position = Vector3(0.0, 2.5, 0.0)
			lamp.add_child(pole)
			var head := MeshInstance3D.new()
			head.mesh = head_mesh
			head.material_override = lamp_mat
			head.position = Vector3(0.0, 5.0, 0.0)
			lamp.add_child(head)
			container.add_child(lamp)
			placed += 1


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
	var colors := PackedColorArray()
	var meshed := 0

	for b in buildings:
		var ring := _project_ring(b["footprint"], proj)
		var geo := CityBuilder.extrude_prism(ring, 0.0, float(b["height_m"]))
		if geo.is_empty():
			continue
		_append_geo(verts, norms, idx, geo)
		# Per-building wall tint, read by the facade shader as vertex COLOR.
		var tint := CityBuilder.building_color(int(b.get("id", meshed)))
		for _i in (geo["vertices"] as PackedVector3Array).size():
			colors.append(tint)
		meshed += 1

	if verts.is_empty():
		return 0

	var mesh := CityBuilder.arrays_to_mesh(
		{"vertices": verts, "normals": norms, "indices": idx, "colors": colors}
	)
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
	var uvs := PackedVector2Array()

	for r in roads:
		var path := _project_ring(r["path"], proj)
		var geo := CityBuilder.road_ribbon(path, float(r["width_m"]), 0.05)
		if geo.is_empty():
			continue
		_append_geo(verts, norms, idx, geo)
		uvs.append_array(geo["uvs"])

	if verts.is_empty():
		return
	var mesh := CityBuilder.arrays_to_mesh(
		{"vertices": verts, "normals": norms, "indices": idx, "uvs": uvs}
	)
	mesh.surface_set_material(0, _road_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Roads"
	mi.mesh = mesh
	add_child(mi)


## TimeOfDay (group "night_emissive") fades building windows in/out, 0..1.
func set_night_amount(amount: float) -> void:
	var shaded := _building_mat as ShaderMaterial
	if shaded != null:
		shaded.set_shader_parameter("night_mix", amount)


## Move the player + spawn marker onto the road vertex nearest the origin so the
## player never starts trapped inside a building footprint.
func _place_actors_on_street(roads: Array, proj: GeoProjection) -> void:
	var best := Vector3.ZERO
	var best_dist := INF
	for r in roads:
		for pair in r["path"]:
			var p := proj.to_local(pair[0], pair[1])
			var d := p.length()
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
	# Procedural facade/asphalt shaders — no texture assets. Fall back to plain
	# greybox materials so the district still builds if a shader goes missing.
	# (Consolidation per LOOP_HANDOFF: facade.gdshader won over the parallel
	# building.gdshader/building_windows.gdshader; TimeOfDay drives its
	# night_mix uniform through set_night_amount.)
	_building_mat = _shader_or_fallback("res://shaders/facade.gdshader", Color(0.62, 0.63, 0.66))
	_road_mat = _shader_or_fallback("res://shaders/road.gdshader", Color(0.33, 0.32, 0.31))

	_roof_mat = StandardMaterial3D.new()
	_roof_mat.albedo_color = Color(0.4, 0.41, 0.45)
	_roof_mat.roughness = 0.95


static func _shader_or_fallback(path: String, fallback: Color) -> Material:
	var shader := load(path) as Shader
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		return mat
	var std := StandardMaterial3D.new()
	std.albedo_color = fallback
	std.roughness = 0.9
	# Double-sided keeps interiors lit if a footprint winds oddly.
	std.cull_mode = BaseMaterial3D.CULL_DISABLED
	return std
