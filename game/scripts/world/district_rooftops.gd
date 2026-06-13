class_name DistrictRooftops
extends RefCounted
## Rooftop superstructure for streamed districts, extracted from DistrictLoader to
## keep that file under the line cap (mirrors DistrictFacadePanels / BuildingDoors).
##
## Breaks up the flat-topped skyline: mechanical penthouses (scaled boxes) on
## mid/high-rises, water tanks + AC condensers on the rest, and antenna masts
## capped with a red aircraft-warning beacon on the genuine towers. Everything
## batches into a handful of MultiMesh draw calls (one per prop type) so hundreds
## of props cost almost nothing.

const PLACE_CAP := 650


static func build(parent: Node3D, buildings: Array, proj: GeoProjection) -> void:
	var ac_tf: Array[Transform3D] = []
	var tank_tf: Array[Transform3D] = []
	var house_tf: Array[Transform3D] = []
	var mast_tf: Array[Transform3D] = []
	var beacon_tf: Array[Transform3D] = []

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	for b in buildings:
		if placed >= PLACE_CAP:
			break
		var height := float(b.get("height_m", 0.0))
		if height < 6.0:
			continue
		var ring := _project_ring(b["footprint"], proj)
		if ring.size() < 3:
			continue
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		var centre := Vector2.ZERO
		for p in ring:
			centre += p
			mn = mn.min(p)
			mx = mx.max(p)
		centre /= float(ring.size())
		var ext := mx - mn  # footprint extent (metres) in x/z
		var roof := Vector3(centre.x, height, centre.y)

		# Mechanical penthouse — a smaller box, sized to a fraction of the roof,
		# is the single biggest break to the dead-flat silhouette from afar.
		if height >= 22.0 and ext.x > 6.0 and ext.y > 6.0:
			var phx := clampf(ext.x * rng.randf_range(0.3, 0.5), 3.0, 16.0)
			var phz := clampf(ext.y * rng.randf_range(0.3, 0.5), 3.0, 16.0)
			var phh := rng.randf_range(3.0, 6.0)
			var off := Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5))
			house_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(phx, phh, phz)), roof + off + Vector3(0, phh * 0.5, 0)
				)
			)

		# Antenna mast + always-on red beacon on the real high-rises; a water tank
		# on mid-rises; a small stair/elevator bulkhead on the low-rise Deco roofs
		# so even the two-storey hotels aren't bare flat boxes.
		if height >= 50.0:
			var mh := rng.randf_range(8.0, 18.0)
			mast_tf.append(
				Transform3D(Basis.from_scale(Vector3(1, mh, 1)), roof + Vector3(0, mh * 0.5, 0))
			)
			beacon_tf.append(Transform3D(Basis.IDENTITY, roof + Vector3(0, mh, 0)))
		elif height >= 12.0:
			tank_tf.append(
				Transform3D(
					Basis.IDENTITY,
					roof + Vector3(rng.randf_range(-2.5, 2.5), 1.1, rng.randf_range(-2.5, 2.5))
				)
			)
		elif ext.x > 4.0 and ext.y > 4.0:
			var bw := clampf(minf(ext.x, ext.y) * rng.randf_range(0.25, 0.4), 2.0, 5.0)
			var bh := rng.randf_range(1.8, 2.8)
			house_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(bw, bh, bw)),
					roof + Vector3(rng.randf_range(-1.0, 1.0), bh * 0.5, rng.randf_range(-1.0, 1.0))
				)
			)

		# AC condenser on (almost) every roof, randomly yawed.
		var ac_basis := Basis(Vector3.UP, rng.randf() * TAU)
		ac_tf.append(
			Transform3D(
				ac_basis, roof + Vector3(rng.randf_range(-3, 3), 0.6, rng.randf_range(-3, 3))
			)
		)
		placed += 1

	var container := Node3D.new()
	container.name = "Rooftops"
	parent.add_child(container)

	var tank_mat := StandardMaterial3D.new()
	tank_mat.albedo_color = Color(0.4, 0.36, 0.3)
	tank_mat.roughness = 0.85
	var ac_mat := StandardMaterial3D.new()
	ac_mat.albedo_color = Color(0.5, 0.51, 0.54)
	ac_mat.metallic = 0.5
	ac_mat.roughness = 0.5
	var house_mat := StandardMaterial3D.new()
	house_mat.albedo_color = Color(0.42, 0.43, 0.45)
	house_mat.roughness = 0.8
	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.12, 0.12, 0.13)
	mast_mat.metallic = 0.7
	mast_mat.roughness = 0.45
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = Color(0.9, 0.1, 0.08)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.12, 0.06)
	beacon_mat.emission_energy_multiplier = 3.0

	var tank_mesh := CylinderMesh.new()
	tank_mesh.top_radius = 1.1
	tank_mesh.bottom_radius = 1.1
	tank_mesh.height = 2.2
	var ac_mesh := BoxMesh.new()
	ac_mesh.size = Vector3(2.6, 1.2, 2.0)
	var house_mesh := BoxMesh.new()  # unit box, scaled per instance
	house_mesh.size = Vector3.ONE
	var mast_mesh := CylinderMesh.new()  # unit-height, scaled per instance
	mast_mesh.top_radius = 0.1
	mast_mesh.bottom_radius = 0.22
	mast_mesh.height = 1.0
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.32
	beacon_mesh.height = 0.64

	_layer("ACUnits", ac_mesh, ac_mat, ac_tf, container)
	_layer("WaterTanks", tank_mesh, tank_mat, tank_tf, container)
	_layer("Penthouses", house_mesh, house_mat, house_tf, container)
	_layer("Masts", mast_mesh, mast_mat, mast_tf, container)
	_layer("Beacons", beacon_mesh, beacon_mat, beacon_tf, container)


## Pack a set of instance transforms into one MultiMeshInstance3D (a single draw
## call) under `parent`. No-op for an empty layer.
static func _layer(
	layer_name: String, mesh: Mesh, mat: Material, transforms: Array[Transform3D], parent: Node3D
) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


static func _project_ring(raw: Array, proj: GeoProjection) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for pair in raw:
		ring.append(proj.to_local_2d(pair[0], pair[1]))
	return ring
