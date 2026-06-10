class_name OrbitCamera
extends Node3D
## Mouse-look camera rig: this node yaws, the SpringArm child pitches.
##
## The SpringArm keeps the camera from clipping through world geometry
## (its collision mask excludes the player's layer).

const PITCH_MIN: float = -1.2
const PITCH_MAX: float = 0.5

@export var sensitivity: float = 0.003

@onready var _arm: SpringArm3D = $SpringArm


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	rotation.y -= motion.relative.x * sensitivity
	_arm.rotation.x = clampf(
		_arm.rotation.x - motion.relative.y * sensitivity, PITCH_MIN, PITCH_MAX
	)
