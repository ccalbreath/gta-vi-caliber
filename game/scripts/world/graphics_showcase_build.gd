class_name ShowcaseBuild
extends RefCounted
## Stateless construction helpers extracted from graphics_showcase.gd to keep
## that scene script under the 1000-line cap. All functions are pure: they take
## an explicit parent/target and touch no showcase instance state, so they read
## and behave identically to the in-scene methods they replaced.


## Roof footprint record (centre + extent) for one building ring, consumed by
## build_rooftop_props.
static func roof_record(ring: PackedVector2Array, h: float) -> Dictionary:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
		mn = mn.min(p)
		mx = mx.max(p)
	centre /= float(ring.size())
	return {"roof": Vector3(centre.x, h, centre.y), "ext": mx - mn}


## Rooftop superstructure (district_loader._build_rooftops pattern): mechanical
## penthouses on mid/high-rises, masts + red aircraft beacons on the towers,
## water tanks on mid-rises and an AC condenser on every roof. Each prop type
## batches into ONE MultiMesh draw under a "Rooftops" node added to `parent`.
static func build_rooftop_props(parent: Node3D, centers: Array) -> void:
	var ac_tf: Array[Transform3D] = []
	var tank_tf: Array[Transform3D] = []
	var house_tf: Array[Transform3D] = []
	var mast_tf: Array[Transform3D] = []
	var beacon_tf: Array[Transform3D] = []
	# (A) Tower crowns: shrinking setback steps + recessed mechanical penthouse on
	# the genuine towers, and a thin tar-grey parapet lip on the mid-rises so a
	# flat top reads as a capped roof, not a wall-tinted slab. Separate layers so
	# each batches into ONE MultiMesh draw.
	var step_tf: Array[Transform3D] = []
	var parapet_tf: Array[Transform3D] = []
	var penthouse_tf: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	for rec in centers:
		var roof: Vector3 = rec["roof"]
		var ext: Vector2 = rec["ext"]
		var h := roof.y

		# (A) Genuine tower (h>=60): a real terminating profile. 2 shrinking setback
		# steps (0.72x then 0.5x the roof footprint, 3-6 m tall) capped by a recessed
		# mechanical penthouse (~0.45x, 4 m). The antenna mast + beacon below then
		# perch on top of the penthouse, not the bare lid.
		var crown_top := roof.y  # where the mast/beacon should anchor
		if h >= 60.0:
			var s1_h := rng.randf_range(3.5, 6.0)
			step_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(ext.x * 0.72, s1_h, ext.y * 0.72)),
					roof + Vector3(0.0, s1_h * 0.5, 0.0)
				)
			)
			var s2_y := roof.y + s1_h
			var s2_h := rng.randf_range(3.0, 5.0)
			step_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(ext.x * 0.5, s2_h, ext.y * 0.5)),
					Vector3(roof.x, s2_y + s2_h * 0.5, roof.z)
				)
			)
			var ph_y := s2_y + s2_h
			penthouse_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(ext.x * 0.45, 4.0, ext.y * 0.45)),
					Vector3(roof.x, ph_y + 2.0, roof.z)
				)
			)
			crown_top = ph_y + 4.0
		elif h >= 30.0:
			# Mid-rise parapet lip: thin ring slightly proud of the roof edge in
			# darker tar-grey, 0.6 m tall, so the flat top caps cleanly.
			parapet_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(ext.x * 1.04, 0.6, ext.y * 1.04)),
					roof + Vector3(0.0, 0.3, 0.0)
				)
			)

		# Mechanical penthouse / bulkhead on mid/high-rises — the single biggest
		# break to a dead-flat roofline. Enlarged (~3x4x5 m floor minimum) so it
		# still reads at the 380 m aerial range. Towers already got a dedicated
		# recessed penthouse above, so skip them here.
		if h >= 22.0 and h < 60.0 and ext.x > 6.0 and ext.y > 6.0:
			var off := Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5))
			house_tf.append(
				Transform3D(
					Basis.from_scale(
						Vector3(maxf(ext.x * 0.45, 5.0), 4.0, maxf(ext.y * 0.45, 3.0))
					),
					roof + off + Vector3(0.0, 2.6, 0.0)
				)
			)

		# Antenna mast + always-on red beacon on the genuine towers, anchored on
		# top of the crown profile; a water tank on the mid-rises.
		if h >= 50.0:
			var mh := rng.randf_range(6.0, 9.0)
			mast_tf.append(
				Transform3D(
					Basis.from_scale(Vector3(1.0, mh, 1.0)),
					Vector3(roof.x, crown_top + mh * 0.5, roof.z)
				)
			)
			beacon_tf.append(Transform3D(Basis.IDENTITY, Vector3(roof.x, crown_top + mh, roof.z)))
		elif h >= 12.0:
			tank_tf.append(
				Transform3D(
					Basis.IDENTITY,
					roof + Vector3(rng.randf_range(-2.5, 2.5), 1.1, rng.randf_range(-2.5, 2.5))
				)
			)

		# AC condenser on every roof, randomly yawed.
		var ac_basis := Basis(Vector3.UP, rng.randf() * TAU)
		ac_tf.append(
			Transform3D(
				ac_basis,
				roof + Vector3(rng.randf_range(-3.0, 3.0), 0.6, rng.randf_range(-3.0, 3.0))
			)
		)

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
	# (A) Tower setback steps: pale concrete to read against the glass curtain wall.
	var step_mat := StandardMaterial3D.new()
	step_mat.albedo_color = Color(0.46, 0.47, 0.50)
	step_mat.roughness = 0.85
	# (A) Recessed mechanical penthouse on the tower crown — darker than the steps.
	var penthouse_mat := StandardMaterial3D.new()
	penthouse_mat.albedo_color = Color(0.30, 0.31, 0.34)
	penthouse_mat.roughness = 0.85
	# (A) Mid-rise parapet lip: dark tar-grey so the flat top reads as a capped roof.
	var parapet_mat := StandardMaterial3D.new()
	parapet_mat.albedo_color = Color(0.30, 0.31, 0.34)
	parapet_mat.roughness = 0.9
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
	var step_mesh := BoxMesh.new()  # unit box, scaled per instance (A)
	step_mesh.size = Vector3.ONE
	var parapet_mesh := BoxMesh.new()  # unit box, scaled per instance (A)
	parapet_mesh.size = Vector3.ONE
	var penthouse_mesh := BoxMesh.new()  # unit box, scaled per instance (A)
	penthouse_mesh.size = Vector3.ONE
	var mast_mesh := CylinderMesh.new()  # unit-height, scaled per instance
	mast_mesh.top_radius = 0.1
	mast_mesh.bottom_radius = 0.22
	mast_mesh.height = 1.0
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.32
	beacon_mesh.height = 0.64

	prop_layer("ACUnits", ac_mesh, ac_mat, ac_tf, container)
	prop_layer("WaterTanks", tank_mesh, tank_mat, tank_tf, container)
	prop_layer("Penthouses", house_mesh, house_mat, house_tf, container)
	prop_layer("TowerSteps", step_mesh, step_mat, step_tf, container)
	prop_layer("Parapets", parapet_mesh, parapet_mat, parapet_tf, container)
	prop_layer("TowerPenthouses", penthouse_mesh, penthouse_mat, penthouse_tf, container)
	prop_layer("Masts", mast_mesh, mast_mat, mast_tf, container)
	prop_layer("Beacons", beacon_mesh, beacon_mat, beacon_tf, container)


## One MultiMeshInstance3D per prop type; custom_aabb grown so off-centre
## instances never culling-pop at frame edges.
static func prop_layer(
	layer_name: String, mesh: Mesh, mat: Material, transforms: Array[Transform3D], parent: Node3D
) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	var bounds := AABB(transforms[0].origin, Vector3.ZERO)
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		bounds = bounds.expand(transforms[i].origin)
	mm.custom_aabb = bounds.grow(8.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


## AABB of all meshes under `node`, accumulating the full transform chain up to
## (excluding) `node` — nested/scaled Meshy exports break with mi.transform alone.
static func node_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var seeded := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var walker: Node = mi
		while walker != null and walker != node:
			if walker is Node3D:
				xf = (walker as Node3D).transform * xf
			walker = walker.get_parent()
		var box := xf * mi.get_aabb()
		if not seeded:
			out = box
			seeded = true
		else:
			out = out.merge(box)
	return out


## (B) Author lit headlight/taillight quads on a placed car for the frozen-dusk
## scene. `aabb` is the car-local mesh bounds (pre-scale); quads are parented under
## the car so they inherit its scale + seat + yaw. Red emissive at the rear corners,
## cool-white at the front, energy high enough to bleed past glow_hdr_threshold 1.6.
static func add_car_lights(car: Node3D, aabb: AABB) -> void:
	# The car was normalised on its longer horizontal axis -> that is its length.
	var long_is_z := aabb.size.z >= aabb.size.x
	var half_len := (aabb.size.z if long_is_z else aabb.size.x) * 0.5
	var half_wid := (aabb.size.x if long_is_z else aabb.size.z) * 0.5
	var c := aabb.get_center()
	# Seat lights low on the body (just above the AABB floor), inset off the corners.
	var y := aabb.position.y + aabb.size.y * 0.32
	var inset := half_wid * 0.35
	var lamp_w := aabb.size.length() * 0.05  # ~0.25 m once scaled to target_len
	var lamp_h := lamp_w * 0.48

	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.4, 0.02, 0.01)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.05, 0.03)
	tail_mat.emission_energy_multiplier = 7.0
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.6, 0.62, 0.66)
	head_mat.emission_enabled = true
	head_mat.emission = Color(0.9, 0.95, 1.0)
	head_mat.emission_energy_multiplier = 6.0
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for s in [-1.0, 1.0]:
		var sf := float(s)
		var lat: float = (
			c.x + sf * (half_wid - inset) if long_is_z else c.z + sf * (half_wid - inset)
		)
		# Rear (+local axis) gets taillights, front (-axis) gets headlights.
		for nose in [-1.0, 1.0]:
			var nf := float(nose)
			var along: float = c.z + nf * half_len if long_is_z else c.x + nf * half_len
			var pos: Vector3 = Vector3(lat, y, along) if long_is_z else Vector3(along, y, lat)
			var quad := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(lamp_w, lamp_h)
			qm.material = head_mat if nf < 0.0 else tail_mat
			quad.mesh = qm
			quad.position = pos
			# Face the quad outward along the car's long axis.
			if long_is_z:
				quad.rotation.y = 0.0 if nf > 0.0 else PI
			else:
				quad.rotation.y = (PI * 0.5) if nf > 0.0 else (-PI * 0.5)
			car.add_child(quad)


## Surface-override styling: albedo tint (parked-car paint variety) and/or
## clearcoat (hero-car lacquer). Never touches metallic/roughness factors.
static func style_car(car: Node3D, tint: Color, coat: bool, coat_value: float = 0.6) -> void:
	if tint.is_equal_approx(Color.WHITE) and not coat:
		return
	for child in car.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var std := mi.get_active_material(s) as StandardMaterial3D
			if std == null:
				continue
			var dup := std.duplicate() as StandardMaterial3D
			if not tint.is_equal_approx(Color.WHITE):
				dup.albedo_color = dup.albedo_color * tint
			if coat:
				dup.clearcoat_enabled = true
				dup.clearcoat = coat_value
				dup.clearcoat_roughness = 0.1
			mi.set_surface_override_material(s, dup)
