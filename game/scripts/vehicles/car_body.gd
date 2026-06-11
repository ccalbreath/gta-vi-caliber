class_name CarBody
extends Node3D
## Swaps the greybox car boxes for a sleek procedural body and metallic wheel
## rims, once in _ready.
##
## Sits as a child of the Car (VehicleBody3D). It only rewrites the mesh/material
## of the existing Chassis node, hides the Cabin box (the lofted body already
## carries the roofline), and parents a chrome hub to each wheel mesh — the
## physics body, VehicleWheel3D nodes and collision shape are untouched. Every
## lookup is null-guarded so a mid-edit scene can't crash the headless gate.

const WHEELS: Array[String] = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]

## Body paint; metallic flake by default. Swap per-vehicle for colour variety.
@export var paint_color: Color = Color(0.74, 0.18, 0.15)


func _ready() -> void:
	var car: Node = get_parent()
	if car == null:
		return

	var chassis: MeshInstance3D = car.get_node_or_null("Chassis") as MeshInstance3D
	if chassis != null:
		var mesh := CarMesh.to_mesh_glazed(CarMesh.body())
		chassis.mesh = mesh
		chassis.set_surface_override_material(0, _paint())
		if mesh != null and mesh.get_surface_count() > 1:
			chassis.set_surface_override_material(1, _glass())
		chassis.position = Vector3.ZERO  # body is authored in car space already

	var cabin: MeshInstance3D = car.get_node_or_null("Cabin") as MeshInstance3D
	if cabin != null:
		cabin.visible = false

	var rim := _rim_material()
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


func _paint() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = paint_color
	mat.metallic = 0.55
	mat.roughness = 0.26
	# Clearcoat-ish sheen for an automotive paint read.
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _glass() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.05, 0.07)
	mat.metallic = 0.4
	mat.roughness = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _rim_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.74, 0.78)
	mat.metallic = 0.95
	mat.roughness = 0.22
	return mat
