class_name BoatBody
extends Node3D
## Swaps the greybox boat hull box for a sleek procedural hull, once in _ready.
##
## Sits as a child of the Boat (RigidBody3D). Only rewrites the Hull mesh/material;
## the float points, collision and Console are untouched. Null-guarded so a
## mid-edit scene can't crash the headless gate.

@export var hull_color: Color = Color(0.93, 0.93, 0.9)


func _ready() -> void:
	var boat: Node = get_parent()
	if boat == null:
		return
	var hull: MeshInstance3D = boat.get_node_or_null("Hull") as MeshInstance3D
	if hull == null:
		return
	hull.mesh = BoatMesh.to_mesh(BoatMesh.hull())
	hull.material_override = _gelcoat()
	hull.position = Vector3.ZERO  # hull authored with keel near y=0

	# Dark dashboard console with a raked glass windscreen, to match the car.
	var console: MeshInstance3D = boat.get_node_or_null("Console") as MeshInstance3D
	if console != null:
		var dash := StandardMaterial3D.new()
		dash.albedo_color = Color(0.14, 0.15, 0.17)
		dash.metallic = 0.3
		dash.roughness = 0.5
		console.material_override = dash
		var glass := MeshInstance3D.new()
		var pane := BoxMesh.new()
		pane.size = Vector3(0.95, 0.42, 0.03)
		glass.mesh = pane
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.06, 0.1, 0.14)
		gmat.roughness = 0.05
		gmat.metallic = 0.3
		gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.material_override = gmat
		glass.position = Vector3(0.0, 0.32, -0.42)
		glass.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
		console.add_child(glass)


func _gelcoat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = hull_color
	mat.metallic = 0.2
	mat.roughness = 0.18
	# Marine gelcoat is a glossy clear lacquer over the hull pigment — a clearcoat
	# layer gives it the wet, sky-reflecting sheen a fibreglass hull has.
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.8
	mat.clearcoat_roughness = 0.06
	mat.rim_enabled = true
	mat.rim = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
