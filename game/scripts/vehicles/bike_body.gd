class_name BikeBody
extends Node3D
## Swaps the greybox bike's single frame box for a recognisable motorbike
## silhouette — engine block, rounded fuel tank, seat, front fork, handlebars —
## and adds chrome wheel rims, once in _ready.
##
## Sits as a child of the Bike (VehicleBody3D). It hides the Frame box and adds
## child meshes; the physics body, VehicleWheel3D nodes and collision are
## untouched. Built from primitives (no UVs needed). Null-guarded.

@export var paint_color: Color = Color(0.16, 0.5, 0.62)


func _ready() -> void:
	var bike: Node = get_parent()
	if bike == null:
		return
	var frame: MeshInstance3D = bike.get_node_or_null("Frame") as MeshInstance3D
	if frame != null:
		frame.visible = false

	var metal := _mat(Color(0.13, 0.13, 0.15), 0.7, 0.5)
	var paint := _mat(paint_color, 0.2, 0.3)
	var seat := _mat(Color(0.05, 0.05, 0.06), 0.0, 0.8)
	var chrome := _mat(Color(0.75, 0.77, 0.8), 0.95, 0.2)

	# Engine/gearbox mass low between the wheels.
	add_child(_box(Vector3(0.34, 0.42, 0.72), Vector3(0.0, 0.5, 0.05), metal))
	# Rounded fuel tank up front.
	add_child(_capsule(0.17, 0.36, Vector3(0.0, 0.86, -0.22), Vector3(90.0, 0.0, 0.0), paint))
	# Seat behind the tank.
	add_child(_box(Vector3(0.26, 0.1, 0.66), Vector3(0.0, 0.84, 0.34), seat))
	# Front fork raking down to the front wheel.
	add_child(_cyl(0.035, 0.66, Vector3(0.0, 0.66, -0.66), Vector3(-32.0, 0.0, 0.0), chrome))
	# Handlebars.
	add_child(_cyl(0.022, 0.52, Vector3(0.0, 0.99, -0.52), Vector3(0.0, 0.0, 90.0), metal))

	for wheel in ["WheelFront", "WheelRear"]:
		var wm: MeshInstance3D = (
			bike.get_node_or_null("%s/%sMesh" % [wheel, wheel]) as MeshInstance3D
		)
		if wm == null:
			continue
		wm.add_child(_cyl(0.17, 0.16, Vector3.ZERO, Vector3.ZERO, chrome))


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, pos, Vector3.ZERO, mat)


func _capsule(
	radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material
) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _instance(mesh, pos, rot, mat)


func _cyl(
	radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _instance(mesh, pos, rot, mat)


func _instance(mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	return mi
