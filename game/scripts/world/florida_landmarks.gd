class_name FloridaLandmarks
extends RefCounted
## Procedural landmark + decoration mesh builders for FloridaBackdrop.
##
## Split out of florida_backdrop.gd to keep each file within the project line
## budget. Reads shared materials and land height off the owning backdrop; every
## shape is generated procedurally here, none copied from reference map data.

var _b: FloridaBackdrop


func _init(backdrop: FloridaBackdrop) -> void:
	_b = backdrop


func add_neon_light_cluster(parent: Node3D, scale_factor: float) -> void:
	var light_specs := [
		{
			"name": "CyanNeonLight",
			"pos": Vector3(-24.0, 14.0, -28.0),
			"color": Color(0.28, 0.95, 1.0),
			"energy": 2.6
		},
		{
			"name": "PinkNeonLight",
			"pos": Vector3(18.0, 20.0, -18.0),
			"color": Color(1.0, 0.22, 0.55),
			"energy": 2.25
		},
		{
			"name": "AmberLobbyLight",
			"pos": Vector3(-6.0, 7.0, -24.0),
			"color": Color(1.0, 0.58, 0.22),
			"energy": 1.8
		},
		{
			"name": "PoolGlowLight",
			"pos": Vector3(30.0, 4.0, 20.0),
			"color": Color(0.22, 0.92, 1.0),
			"energy": 1.55
		}
	]
	for spec in light_specs:
		var light := OmniLight3D.new()
		light.name = String(spec["name"])
		light.position = spec["pos"]
		light.light_color = spec["color"]
		light.light_energy = float(spec["energy"])
		light.omni_range = 34.0 * scale_factor
		light.shadow_enabled = false
		light.add_to_group("night_lights")
		parent.add_child(light, true)


func add_lighthouse(parent: Node, xz: Vector2, yaw: float) -> void:
	var lighthouse := Node3D.new()
	lighthouse.name = "TorchKeyLight"
	lighthouse.position = Vector3(xz.x, _b.land_y, xz.y)
	lighthouse.rotation.y = yaw
	parent.add_child(lighthouse, true)

	var tower := MeshInstance3D.new()
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 4.0
	tower_mesh.bottom_radius = 7.0
	tower_mesh.height = 64.0
	tower_mesh.radial_segments = 18
	tower.mesh = tower_mesh
	tower.material_override = _b._resort_white_mat
	tower.position = Vector3(0.0, 32.0, 0.0)
	lighthouse.add_child(tower)

	for y in [14.0, 30.0, 48.0]:
		var band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new()
		band_mesh.top_radius = 4.4
		band_mesh.bottom_radius = 5.4
		band_mesh.height = 1.2
		band_mesh.radial_segments = 18
		band.mesh = band_mesh
		band.material_override = _b._resort_coral_mat
		band.position = Vector3(0.0, y, 0.0)
		lighthouse.add_child(band)

	var lantern := MeshInstance3D.new()
	var lantern_mesh := CylinderMesh.new()
	lantern_mesh.top_radius = 4.6
	lantern_mesh.bottom_radius = 4.6
	lantern_mesh.height = 5.0
	lantern_mesh.radial_segments = 18
	lantern.mesh = lantern_mesh
	lantern.material_override = _b._glass_mat
	lantern.position = Vector3(0.0, 69.0, 0.0)
	lighthouse.add_child(lantern)

	var beacon := MeshInstance3D.new()
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 1.4
	beacon_mesh.height = 2.8
	beacon.mesh = beacon_mesh
	beacon.material_override = _b._warning_light_mat
	beacon.position = Vector3(0.0, 72.0, 0.0)
	lighthouse.add_child(beacon)


func add_observation_wheel(parent: Node, xz: Vector2, yaw: float) -> void:
	var wheel := Node3D.new()
	wheel.name = "SunsetWheel"
	wheel.position = Vector3(xz.x, _b.land_y, xz.y)
	wheel.rotation.y = yaw
	parent.add_child(wheel, true)

	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 40.0
	rim_mesh.outer_radius = 42.0
	rim_mesh.ring_segments = 64
	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.material_override = _b._steel_mat
	rim.position = Vector3(0.0, 48.0, 0.0)
	rim.rotation.x = PI * 0.5
	wheel.add_child(rim)

	var spoke_mesh := BoxMesh.new()
	spoke_mesh.size = Vector3(0.65, 0.65, 82.0)
	for i in range(12):
		var spoke := MeshInstance3D.new()
		spoke.name = "WheelSpoke"
		spoke.mesh = spoke_mesh
		spoke.material_override = _b._steel_mat
		spoke.position = Vector3(0.0, 48.0, 0.0)
		spoke.rotation.x = PI * 0.5
		spoke.rotation.z = TAU * float(i) / 12.0
		wheel.add_child(spoke)

	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(5.0, 2.8, 3.0)
	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var cabin := MeshInstance3D.new()
		cabin.name = "WheelCabin"
		cabin.mesh = cabin_mesh
		cabin.material_override = _b._resort_aqua_mat if i % 2 == 0 else _b._resort_coral_mat
		cabin.position = Vector3(cos(angle) * 42.0, 48.0 + sin(angle) * 42.0, 0.0)
		wheel.add_child(cabin)

	for x in [-16.0, 16.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(1.5, 58.0, 1.5)
		leg.mesh = leg_mesh
		leg.material_override = _b._steel_mat
		leg.position = Vector3(x, 29.0, 0.0)
		leg.rotation.z = 0.28 * signf(x)
		wheel.add_child(leg)


func add_launch_tower(parent: Node, xz: Vector2, yaw: float) -> void:
	var launch := Node3D.new()
	launch.name = "AtlasPointLaunch"
	launch.position = Vector3(xz.x, _b.land_y, xz.y)
	launch.rotation.y = yaw
	parent.add_child(launch, true)

	var tower_mesh := BoxMesh.new()
	tower_mesh.size = Vector3(8.0, 86.0, 8.0)
	var tower := MeshInstance3D.new()
	tower.mesh = tower_mesh
	tower.material_override = _b._steel_mat
	tower.position = Vector3(0.0, 43.0, 0.0)
	launch.add_child(tower)

	for y in [16.0, 32.0, 48.0, 64.0, 80.0]:
		var deck := MeshInstance3D.new()
		var deck_mesh := BoxMesh.new()
		deck_mesh.size = Vector3(28.0, 1.2, 18.0)
		deck.mesh = deck_mesh
		deck.material_override = _b._concrete_mat
		deck.position = Vector3(8.0, y, 0.0)
		launch.add_child(deck)

	var rocket := MeshInstance3D.new()
	var rocket_mesh := CylinderMesh.new()
	rocket_mesh.top_radius = 2.0
	rocket_mesh.bottom_radius = 2.6
	rocket_mesh.height = 58.0
	rocket_mesh.radial_segments = 20
	rocket.mesh = rocket_mesh
	rocket.material_override = _b._resort_white_mat
	rocket.position = Vector3(-18.0, 29.0, 0.0)
	launch.add_child(rocket)

	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 2.1
	nose_mesh.height = 8.0
	nose_mesh.radial_segments = 20
	nose.mesh = nose_mesh
	nose.material_override = _b._resort_coral_mat
	nose.position = Vector3(-18.0, 62.0, 0.0)
	launch.add_child(nose)

	var flame := MeshInstance3D.new()
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 1.2
	flame_mesh.bottom_radius = 4.5
	flame_mesh.height = 13.0
	flame_mesh.radial_segments = 16
	flame.mesh = flame_mesh
	flame.material_override = _b._warning_light_mat
	flame.position = Vector3(-18.0, 0.5, 0.0)
	launch.add_child(flame)


func add_resort_arch(parent: Node, xz: Vector2, yaw: float) -> void:
	var arch := Node3D.new()
	arch.name = "GulfGateArch"
	arch.position = Vector3(xz.x, _b.land_y, xz.y)
	arch.rotation.y = yaw
	parent.add_child(arch, true)

	for x in [-10.0, 10.0]:
		var column := MeshInstance3D.new()
		var column_mesh := CylinderMesh.new()
		column_mesh.top_radius = 2.2
		column_mesh.bottom_radius = 2.8
		column_mesh.height = 22.0
		column_mesh.radial_segments = 16
		column.mesh = column_mesh
		column.material_override = _b._resort_white_mat
		column.position = Vector3(x, 11.0, 0.0)
		arch.add_child(column)

	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(26.0, 4.0, 5.0)
	beam.mesh = beam_mesh
	beam.material_override = _b._resort_aqua_mat
	beam.position = Vector3(0.0, 23.0, 0.0)
	arch.add_child(beam)

	var sign := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(18.0, 2.2, 0.5)
	sign.mesh = sign_mesh
	sign.material_override = _b._neon_mat
	sign.position = Vector3(0.0, 25.0, -2.7)
	arch.add_child(sign)


func add_cabana(parent: Node, xz: Vector2, yaw: float, rng: RandomNumberGenerator) -> void:
	var cabana := Node3D.new()
	cabana.name = "BeachCabana"
	cabana.position = Vector3(xz.x, _b.land_y + 0.35, xz.y)
	cabana.rotation.y = yaw
	parent.add_child(cabana, true)

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(10.0, 2.6, 7.0)
	base.mesh = base_mesh
	base.material_override = _b._resort_white_mat
	base.position = Vector3(0.0, 1.3, 0.0)
	cabana.add_child(base)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(11.5, 2.0, 8.2)
	roof.mesh = roof_mesh
	roof.material_override = _b._resort_coral_mat if rng.randf() < 0.5 else _b._resort_aqua_mat
	roof.position = Vector3(0.0, 3.55, 0.0)
	roof.rotation.z = PI * 0.5
	cabana.add_child(roof)


func add_beach_umbrella(parent: Node, xz: Vector2, yaw: float, index: int) -> void:
	var umbrella := Node3D.new()
	umbrella.name = "BeachUmbrella"
	umbrella.position = Vector3(xz.x, _b.land_y + 0.2, xz.y)
	umbrella.rotation.y = yaw
	parent.add_child(umbrella, true)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 2.5
	pole.mesh = pole_mesh
	pole.material_override = _b._dock_mat
	pole.position = Vector3(0.0, 1.25, 0.0)
	umbrella.add_child(pole)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 1.45
	canopy_mesh.height = 0.65
	canopy_mesh.radial_segments = 12
	canopy.mesh = canopy_mesh
	canopy.material_override = _b._resort_aqua_mat if index % 2 == 0 else _b._resort_coral_mat
	canopy.position = Vector3(0.0, 2.65, 0.0)
	umbrella.add_child(canopy)
