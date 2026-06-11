class_name Ocean
extends MeshInstance3D
## A Gerstner water surface (roadmap M4 "Ocean v1"): CPU-displaces a grid each
## frame from OceanWaves (pure, tested) into a translucent, rolling sea. Exposes
## surface_height(world_x, world_z) so boats can float on the real waves instead
## of a flat line (BoatMotion already has the buoyancy math, it just needs a
## height). A GPU shader is the M6 upgrade; this keeps it scene-simple and lets
## the wave math stay unit-tested.

## Side length of the (square) water patch in metres.
@export var plane_size: float = 80.0
## Grid resolution per side — more = smoother crests, costlier rebuild.
@export var subdivisions: int = 24
@export var water_color: Color = Color(0.10, 0.30, 0.42, 0.78)

var _waves: Array = OceanWaves.default_waves()
var _t: float = 0.0
var _material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("water")  # Floaters find the sea here to sample buoyancy
	_material = StandardMaterial3D.new()
	_material.albedo_color = water_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.roughness = 0.08
	_material.metallic = 0.25
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true  # bake foam into per-vertex colour
	_rebuild()


func _process(delta: float) -> void:
	_t += delta
	_rebuild()


## Wave height (world Y) at a world XZ — for buoyancy. Accounts for this node's
## own position, so a boat far out still floats correctly.
func surface_height(world_x: float, world_z: float) -> float:
	var lx := world_x - global_position.x
	var lz := world_z - global_position.z
	return global_position.y + OceanWaves.surface_height(lx, lz, _t, _waves)


func _rebuild() -> void:
	var n := maxi(subdivisions, 1)
	var step := plane_size / float(n)
	var half := plane_size * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var foam_white := Color(0.85, 0.9, 0.95, 1.0)

	for r in n + 1:
		for c in n + 1:
			var x := -half + float(c) * step
			var z := -half + float(r) * step
			var d := OceanWaves.displacement(x, z, _t, _waves)
			verts.append(Vector3(x + d.x, d.y, z + d.z))
			norms.append(OceanWaves.normal(x, z, _t, _waves))
			colors.append(water_color.lerp(foam_white, OceanWaves.foam(x, z, _t, _waves)))

	var w := n + 1
	for r in n:
		for c in n:
			var i := r * w + c
			idx.append_array([i, i + w, i + 1, i + 1, i + w, i + w + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, _material)
	mesh = am
