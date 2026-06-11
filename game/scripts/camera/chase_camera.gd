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
## Crash shake: peak per-axis angles (rad) at full trauma, decay rate (1/s), a
## non-linear exponent, and noise speed. The car feeds add_shake on impact.
@export var shake_max_angles: Vector3 = Vector3(0.06, 0.05, 0.08)
@export var shake_decay: float = 1.6
@export_range(1.0, 4.0) var shake_exponent: float = 2.0
@export var shake_frequency: float = 20.0

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_noise: FastNoiseLite = null

@onready var _camera: Camera3D = $SpringArm/Camera


func _ready() -> void:
	_camera.fov = base_fov
	_shake_noise = FastNoiseLite.new()


## Add crash-shake trauma in [0, 1]; the car scales this to the collision force.
func add_shake(amount: float) -> void:
	_trauma = CameraShake.add(_trauma, amount)


func _physics_process(delta: float) -> void:
	var body := get_parent() as RigidBody3D
	if body == null:
		return
	var speed := body.linear_velocity.length()
	var blend := CameraFeel.sprint_blend(speed, fov_low_speed, fov_high_speed)
	var target := CameraFeel.fov_for_blend(base_fov, speed_fov_kick, blend)
	_camera.fov = CameraFeel.exp_smoothed(_camera.fov, target, fov_smoothing, delta)
	rotation.y = PI if Input.is_action_pressed("look_behind") else 0.0
	_update_shake(delta)


## Decay trauma and apply the resulting jolt to the leaf camera (isolated from
## the rig's look-behind yaw), sampling decorrelated noise per axis.
func _update_shake(delta: float) -> void:
	_trauma = CameraShake.decay(_trauma, shake_decay, delta)
	if _trauma <= 0.0:
		_camera.rotation = Vector3.ZERO
		return
	_shake_time += delta * shake_frequency
	var noise := Vector3(
		_shake_noise.get_noise_2d(_shake_time, 0.0),
		_shake_noise.get_noise_2d(_shake_time, 100.0),
		_shake_noise.get_noise_2d(_shake_time, 200.0)
	)
	_camera.rotation = CameraShake.angular_offset(_trauma, shake_exponent, shake_max_angles, noise)
