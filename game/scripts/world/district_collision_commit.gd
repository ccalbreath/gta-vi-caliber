class_name DistrictCollisionCommit
extends RefCounted
## Attaches solid building collision to a streamed tile in bounded steps.

const BUILDING_COLLISION := preload("res://scripts/world/building_collision.gd")
const CITY_BUILDER := preload("res://scripts/world/city_builder.gd")
const BUILDINGS_PER_STEP: int = 1

var _buildings: Array
var _projection: Object
var _body: StaticBody3D
var _next_building: int = 0
var _complete: bool = false


func _init(buildings: Array, projection: Object) -> void:
	_buildings = buildings
	_projection = projection


func step(parent: Node3D) -> bool:
	if _complete:
		return true
	if _buildings.is_empty():
		_complete = true
		return true
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		_body.collision_layer = BUILDING_COLLISION.WORLD_LAYER
		_body.add_to_group("world_buildings")
		parent.add_child(_body)

	var attached := 0
	while _next_building < _buildings.size() and attached < BUILDINGS_PER_STEP:
		if _append_building(_buildings[_next_building] as Dictionary):
			attached += 1
		_next_building += 1
	_complete = _next_building >= _buildings.size()
	if _complete and _body.get_child_count() == 0:
		_body.free()
		_body = null
	return _complete


func _append_building(building: Dictionary) -> bool:
	var height := float(building.get("height_m", 0.0))
	if height <= 0.0:
		return false
	var ring := PackedVector2Array()
	for pair in building.get("footprint", []):
		ring.append(_projection.to_local_2d(pair[0], pair[1]))
	ring = CITY_BUILDER.clean_ring(ring)
	if ring.size() < 3:
		return false
	var points := PackedVector3Array()
	for point in ring:
		points.append(Vector3(point.x, 0.0, point.y))
		points.append(Vector3(point.x, height, point.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_body.add_child(collision)
	return true
