class_name DistrictNavigationCommit
extends RefCounted
## Incrementally attaches a prepared navigation mesh without a long scene-tree commit.

const POLYGONS_PER_STEP: int = 16

var _vertices: PackedVector3Array
var _polygons: Array[PackedInt32Array]
var _navigation_mesh: NavigationMesh
var _next_polygon: int = 0
var _complete: bool = false


func _init(vertices: PackedVector3Array, polygons: Array[PackedInt32Array]) -> void:
	_vertices = vertices
	_polygons = polygons


func step(parent: Node3D) -> bool:
	if _complete:
		return true
	if _vertices.is_empty() or _polygons.is_empty():
		_complete = true
		return true
	if _navigation_mesh == null:
		_navigation_mesh = NavigationMesh.new()
		_navigation_mesh.set_vertices(_vertices)

	var batch_end := mini(_next_polygon + POLYGONS_PER_STEP, _polygons.size())
	for index in range(_next_polygon, batch_end):
		_navigation_mesh.add_polygon(_polygons[index])
	_next_polygon = batch_end
	if _next_polygon < _polygons.size():
		return false

	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = _navigation_mesh
	parent.add_child(region)
	_complete = true
	return true
