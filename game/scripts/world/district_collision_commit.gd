class_name DistrictCollisionCommit
extends RefCounted
## Attaches one worker-prepared collision batch per streaming frame.

var _face_batches: Array[PackedVector3Array]
var _body: StaticBody3D
var _next_batch: int = 0
var _complete: bool = false


func _init(face_batches: Array[PackedVector3Array]) -> void:
	_face_batches = face_batches


func step(parent: Node3D) -> bool:
	if _complete:
		return true
	if _face_batches.is_empty():
		_complete = true
		return true
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		parent.add_child(_body)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_face_batches[_next_batch])
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_body.add_child(collision)
	_next_batch += 1
	_complete = _next_batch >= _face_batches.size()
	return _complete
