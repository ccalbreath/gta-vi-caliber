class_name CarBody
extends Node3D
## Swaps the greybox car boxes for a sleek procedural body, metallic wheel rims,
## and the lit detail (head/tail lights, bumpers, sills, plate) that reads as a
## real car, once in _ready.
##
## Sits as a child of the Car (VehicleBody3D). It only rewrites the mesh/material
## of the existing Chassis node, hides the Cabin box (the lofted body already
## carries the roofline), parents a chrome hub to each wheel mesh, and attaches
## emissive light + trim detail to the chassis — the physics body, VehicleWheel3D
## nodes and collision shape are untouched. Every lookup is null-guarded so a
## mid-edit scene can't crash the headless gate.
##
## Material + layout construction lives in static funcs so it unit-tests headless
## (tests/unit/test_car_body_detail.gd) — same testable-core pattern as CarMesh.

const WHEELS: Array[String] = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]

## Car-local geometry landmarks (chassis is repositioned to the car origin in
## _ready, so chassis-local == car-local). Front is -Z (nose), rear is +Z.
const NOSE_Z: float = -2.0
const TAIL_Z: float = 2.0
const HEADLIGHT: Vector3 = Vector3(0.36, 0.58, 0.0)
const TAILLIGHT: Vector3 = Vector3(0.34, 0.66, 0.0)

## Body paint; metallic flake by default. Swap per-vehicle for colour variety.
@export var paint_color: Color = Color(0.74, 0.18, 0.15)
## Silhouette: 0 sedan, 1 SUV, 2 van. -1 = pick at random so traffic varies.
@export var body_style: int = -1


func _ready() -> void:
	var car: Node = get_parent()
	if car == null:
		return

	var style := body_style
	if style < 0:
		var srng := RandomNumberGenerator.new()
		srng.randomize()
		style = srng.randi() % 3
	var chassis: MeshInstance3D = car.get_node_or_null("Chassis") as MeshInstance3D
	if chassis != null:
		var mesh := CarMesh.to_mesh_glazed(CarMesh.body(4.2, 1.9, 28, 24, style))
		chassis.mesh = mesh
		chassis.set_surface_override_material(0, paint_material(paint_color))
		if mesh != null and mesh.get_surface_count() > 1:
			chassis.set_surface_override_material(1, glass_material())
		chassis.position = Vector3.ZERO  # body is authored in car space already
		_build_detail(chassis)

	var cabin: MeshInstance3D = car.get_node_or_null("Cabin") as MeshInstance3D
	if cabin != null:
		cabin.visible = false

	var rim := rim_material()
	for wheel in WHEELS:
		var mesh_node: MeshInstance3D = (
			car.get_node_or_null("%s/%sMesh" % [wheel, wheel]) as MeshInstance3D
		)
		if mesh_node == null:
			continue
		var hub := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.2
		cyl.height = 0.27
		hub.mesh = cyl
		hub.material_override = rim
		mesh_node.add_child(hub)


## Attach the lit detail that separates a premium car from a soap-bar hull:
## emissive head/tail lights (they bloom at the game's dusk-neon TOD), gloss-black
## bumpers + side sills that ground the body, and a rear plate.
func _build_detail(chassis: MeshInstance3D) -> void:
	var head := headlight_material()
	var tail := taillight_material()
	var trim := trim_material()
	# Dark housing bars frame the lamps so they read against same-colour paint —
	# a grille strip at the nose, a light bar at the tail. Lamps sit proud of them.
	_box(chassis, "GrilleFront", Vector3(0.0, HEADLIGHT.y, NOSE_Z), Vector3(1.32, 0.16, 0.05), trim)
	_box(chassis, "HousingRear", Vector3(0.0, TAILLIGHT.y, TAIL_Z), Vector3(1.4, 0.16, 0.05), trim)
	# Headlights — a pair proud of the grille, mirrored across X.
	_box(
		chassis,
		"HeadlightL",
		Vector3(-HEADLIGHT.x, HEADLIGHT.y, NOSE_Z - 0.04),
		Vector3(0.26, 0.12, 0.08),
		head
	)
	_box(
		chassis,
		"HeadlightR",
		Vector3(HEADLIGHT.x, HEADLIGHT.y, NOSE_Z - 0.04),
		Vector3(0.26, 0.12, 0.08),
		head
	)
	# Taillights — wide red strips proud of the dark rear housing so they pop.
	_box(
		chassis,
		"TaillightL",
		Vector3(-TAILLIGHT.x, TAILLIGHT.y, TAIL_Z + 0.05),
		Vector3(0.42, 0.11, 0.06),
		tail
	)
	_box(
		chassis,
		"TaillightR",
		Vector3(TAILLIGHT.x, TAILLIGHT.y, TAIL_Z + 0.05),
		Vector3(0.42, 0.11, 0.06),
		tail
	)
	# Bumpers front and rear.
	_box(chassis, "BumperFront", Vector3(0.0, 0.4, NOSE_Z - 0.04), Vector3(1.5, 0.2, 0.14), trim)
	_box(chassis, "BumperRear", Vector3(0.0, 0.4, TAIL_Z + 0.04), Vector3(1.5, 0.2, 0.14), trim)
	# Side sills — a thin gloss-black skirt down each flank.
	_box(chassis, "SillL", Vector3(-0.92, 0.34, 0.0), Vector3(0.08, 0.1, 3.0), trim)
	_box(chassis, "SillR", Vector3(0.92, 0.34, 0.0), Vector3(0.08, 0.1, 3.0), trim)
	# Rear plate — faintly lit so it reads at night.
	_box(
		chassis,
		"Plate",
		Vector3(0.0, 0.5, TAIL_Z + 0.07),
		Vector3(0.34, 0.13, 0.02),
		plate_material()
	)


func _box(
	parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: StandardMaterial3D
) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## Automotive paint: metallic flake under a glossy clearcoat.
static func paint_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.24
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.7
	mat.clearcoat_roughness = 0.06
	mat.rim_enabled = true
	mat.rim = 0.22
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.05, 0.07)
	mat.metallic = 0.4
	mat.roughness = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func rim_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.74, 0.78)
	mat.metallic = 0.95
	mat.roughness = 0.22
	return mat


## Warm-white emissive — glows under the world's glow/bloom post at dusk.
static func headlight_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.93, 0.85)
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.96, 0.85)
	mat.emission_energy_multiplier = 3.2
	return mat


## Red emissive tail lamp.
static func taillight_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.02, 0.02)
	mat.roughness = 0.12
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.08, 0.03)
	mat.emission_energy_multiplier = 3.4
	return mat


## Gloss-black bumper / sill trim.
static func trim_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.035)
	mat.metallic = 0.3
	mat.roughness = 0.32
	return mat


## Reflective plate, faintly self-lit so it stays legible at night.
static func plate_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.86, 0.8)
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.86, 0.8)
	mat.emission_energy_multiplier = 0.25
	return mat
