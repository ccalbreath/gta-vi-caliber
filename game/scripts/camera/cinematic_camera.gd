class_name CinematicCamera
extends Camera3D
## Dolly camera for trailer/beauty capture (M6 tooling). Glides along a
## CameraPath spline at constant speed with eased ends, aiming at a fixed
## point or a tracked node. Drive it from capture scripts:
##   cam.play_shot(points, 8.0, Vector3(0, 20, 0))
##   await cam.shot_finished

signal shot_finished

## Waypoints of the active shot (world space).
var _points: PackedVector3Array = []
var _arc: PackedFloat32Array = []
var _duration := 0.0
var _elapsed := 0.0
var _look_target := Vector3.ZERO
var _look_node: Node3D = null
var _playing := false


func play_shot(points: PackedVector3Array, duration: float, look_at_point: Vector3) -> void:
	_points = points
	_arc = CameraPath.arc_table(points)
	_duration = maxf(duration, 0.01)
	_elapsed = 0.0
	_look_target = look_at_point
	_look_node = null
	_playing = true
	current = true


## Same, but the aim point follows a moving node (e.g. the player's car).
func play_tracking_shot(points: PackedVector3Array, duration: float, target: Node3D) -> void:
	play_shot(points, duration, target.global_position)
	_look_node = target


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var progress := CameraPath.ease_in_out(_elapsed / _duration)
	var total: float = _arc[_arc.size() - 1]
	var t := CameraPath.t_at_distance(_arc, progress * total)
	global_position = CameraPath.sample(_points, t)
	if _look_node != null:
		_look_target = _look_node.global_position
	if global_position.distance_squared_to(_look_target) > 0.0001:
		look_at(_look_target)
	if _elapsed >= _duration:
		_playing = false
		shot_finished.emit()
