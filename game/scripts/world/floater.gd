class_name Floater
extends Node3D
## Floats its parent RigidBody3D on the nearest Ocean (group "water"). Drop it as
## a child of any rigid body — a boat, a crate, a body in the water — and it bobs
## and self-rights on the Gerstner waves, no per-object tuning. All the numbers
## are in Buoyancy (pure, tested); this samples the surface under each probe and
## applies the forces.

## Hull sample points in the body's local space. The defaults are a ~1 m box's
## four bottom corners; override for a longer hull.
@export var probe_offsets: Array[Vector3] = [
	Vector3(0.5, -0.3, 0.5),
	Vector3(-0.5, -0.3, 0.5),
	Vector3(0.5, -0.3, -0.5),
	Vector3(-0.5, -0.3, -0.5),
]
## Buoyant force per metre of submersion, per probe.
@export var strength: float = 16.0
## Vertical drag while submerged (settles the bob).
@export var damp: float = 1.4
## Submersion past which a probe stops pushing harder (anti-launch).
@export var max_depth: float = 2.0


func _physics_process(_delta: float) -> void:
	var body := get_parent() as RigidBody3D
	if body == null:
		return
	var ocean := _water()
	if ocean == null:
		return

	var depths: Array = []
	for off in probe_offsets:
		var wp := body.global_transform * off
		var depth := Buoyancy.submersion(wp.y, ocean.surface_height(wp.x, wp.z))
		depths.append(depth)
		if depth > 0.0:
			var f := Buoyancy.probe_force(depth, strength, max_depth)
			body.apply_force(Vector3.UP * f, wp - body.global_position)

	var frac := Buoyancy.submerged_fraction(depths)
	if frac > 0.0:
		var drag := Buoyancy.vertical_drag(body.linear_velocity.y, frac, damp)
		body.apply_central_force(Vector3.UP * drag)


func _water() -> Ocean:
	var nodes := get_tree().get_nodes_in_group("water")
	return nodes[0] as Ocean if not nodes.is_empty() else null
