class_name ChaseCamera
extends Node3D
## Vehicle chase camera pivot: rides the car body, widens FOV with speed
## (reusing CameraFeel's pure math), and snaps 180° while the look-behind
## action is held — the instant cut is intentional, matching genre feel.

@export var base_fov: float = 75.0
## Extra FOV blended in at high speed for a sense of velocity.
@export var speed_fov_kick: float = 12.0
@export var fov_smoothing: float = 6.0
## Speeds (m/s) mapping to 0% and 100% of the FOV kick.
@export var fov_low_speed: float = 8.0
@export var fov_high_speed: float = 35.0

@onready var _camera: Camera3D = $SpringArm/Camera


func _ready() -> void:
	_camera.fov = base_fov


func _physics_process(delta: float) -> void:
	var body := get_parent() as RigidBody3D
	if body == null:
		return
	var speed := body.linear_velocity.length()
	var blend := CameraFeel.sprint_blend(speed, fov_low_speed, fov_high_speed)
	var target := CameraFeel.fov_for_blend(base_fov, speed_fov_kick, blend)
	_camera.fov = CameraFeel.exp_smoothed(_camera.fov, target, fov_smoothing, delta)
	rotation.y = PI if Input.is_action_pressed("look_behind") else 0.0
