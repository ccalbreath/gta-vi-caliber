class_name SouthBeachSurf
extends Node3D
## Procedural surf-line ribbons for the South Beach stretch of FloridaBackdrop.
## This is an authored visual layer, not bathymetry: a few foam bands sit just
## offshore and scroll subtly so the playable coast reads as a breaking beach
## instead of a still tidal flat.

const SURF_SHADER := preload("res://shaders/surf_band.gdshader")
const BAND_NAMES := ["OuterBreak", "MidBreak", "ShoreWash"]

@export var map_scale: float = 4.6
@export var surf_y: float = -0.1
@export var band_count: int = 3
@export var first_band_offset_m: float = 24.0
@export var band_spacing_m: float = 10.0
@export var first_band_width_m: float = 18.0
@export var width_falloff_m: float = 4.0

var _time: float = 0.0


func _ready() -> void:
	populate()


func _process(delta: float) -> void:
	_time += delta
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var shader_mat := mi.material_override as ShaderMaterial
		if shader_mat != null:
			shader_mat.set_shader_parameter("u_time", _time)


func populate() -> int:
	if get_child_count() > 0:
		return get_child_count()
	var shore := FloridaMapModel.south_beach_shoreline(map_scale)
	if shore.size() < 2:
		return 0
	var built := 0
	for i in range(mini(band_count, BAND_NAMES.size())):
		var width := maxf(first_band_width_m - float(i) * width_falloff_m, 4.0)
		var offset := first_band_offset_m + float(i) * band_spacing_m
		var path := offset_path(shore, offset)
		var geo := CityBuilder.road_ribbon(path, width, surf_y + float(i) * 0.015)
		if geo.is_empty():
			continue
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = geo["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = geo["normals"]
		arrays[Mesh.ARRAY_TEX_UV] = geo["uvs"]
		arrays[Mesh.ARRAY_INDEX] = geo["indices"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var band := MeshInstance3D.new()
		band.name = BAND_NAMES[i]
		band.mesh = mesh
		band.material_override = _material_for_band(i)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(band)
		built += 1
	return built


## Offset a shoreline path seaward. The authored east coast lives on the right
## side of the polyline, so the helper flips automatically if the candidate path
## drifts inland instead of out over the water.
func offset_path(path: PackedVector2Array, distance_m: float) -> PackedVector2Array:
	var shifted := _offset_path_signed(path, distance_m)
	return shifted if _avg_x(shifted) > _avg_x(path) else _offset_path_signed(path, -distance_m)


func _offset_path_signed(path: PackedVector2Array, distance_m: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.is_empty():
		return out
	for i in range(path.size()):
		var prev := path[maxi(i - 1, 0)]
		var next := path[mini(i + 1, path.size() - 1)]
		var tangent := next - prev
		if tangent.length() < 0.001:
			tangent = Vector2(0.0, -1.0)
		else:
			tangent = tangent.normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		out.append(path[i] + normal * distance_m)
	return out


func _avg_x(path: PackedVector2Array) -> float:
	if path.is_empty():
		return 0.0
	var sum := 0.0
	for p in path:
		sum += p.x
	return sum / float(path.size())


func _material_for_band(index: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURF_SHADER
	mat.set_shader_parameter("u_band_index", float(index))
	mat.set_shader_parameter("u_time", _time)
	mat.set_shader_parameter("u_opacity", 0.72 - float(index) * 0.14)
	mat.set_shader_parameter("u_foam_color", Color(0.95, 0.97, 0.94, 0.86 - float(index) * 0.10))
	return mat
