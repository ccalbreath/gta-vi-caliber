class_name OrbitCamera
extends Node3D
## Mouse-look camera rig: this node yaws, the SpringArm child pitches.
##
## The SpringArm keeps the camera from clipping through world geometry
## (its collision mask excludes the player's layer).

const PITCH_MIN: float = -1.2
const PITCH_MAX: float = 0.5

@export var sensitivity: float = 0.003
## Gamepad right-stick look. Sensitivity is peak turn rate (rad/s) at full
## deflection; deadzone and exponent shape the stick via StickInput so a flick
## and a fine nudge both feel right (mouse stays on `sensitivity` above).
@export var stick_sensitivity: float = 2.6
@export_range(0.0, 0.9) var stick_deadzone: float = 0.18
@export_range(1.0, 4.0) var stick_exponent: float = 1.8
## Over-the-shoulder framing: the arm pivot sits slightly right of the spine.
@export var shoulder_offset: Vector3 = Vector3(0.55, 0.0, 0.0)
@export var base_fov: float = 75.0
## Extra FOV blended in at full sprint speed for a sense of acceleration.
@export var sprint_fov_kick: float = 9.0
@export var fov_smoothing: float = 8.0
## Speeds (horizontal m/s) mapping to 0% and 100% of the FOV kick — keep in
## sync with Player.walk_speed / Player.sprint_speed.
@export var fov_walk_speed: float = 5.0
@export var fov_sprint_speed: float = 8.5
## Field of view while aiming down sights; the view eases to this and the
## sprint FOV kick is suppressed for the duration.
@export var aim_fov: float = 55.0
@export var aim_smoothing: float = 12.0
## How fast a recoil kick eases back to zero (1/s).
@export var recoil_recovery: float = 9.0

var _pitch: float = 0.0
var _recoil: float = 0.0
var _aiming: bool = false

@onready var _arm: SpringArm3D = $SpringArm
@onready var _camera: Camera3D = $SpringArm/Camera


func _ready() -> void:
	_arm.position = shoulder_offset
	_camera.fov = base_fov
	_pitch = _arm.rotation.x


## Hold the camera in the tighter aim FOV. WeaponController sets this each frame
## while the aim button is held.
func set_aiming(value: bool) -> void:
	_aiming = value


## Kick the view up by `amount` radians; it eases back via recoil_recovery so a
## burst climbs and then re-settles on the original aim.
func add_recoil(amount: float) -> void:
	_recoil += amount


## Re-activate this rig's camera (e.g. after stepping out of a vehicle).
func make_current() -> void:
	_camera.current = true


func _physics_process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	var blend := CameraFeel.sprint_blend(speed, fov_walk_speed, fov_sprint_speed)
	var target := CameraFeel.fov_for_blend(base_fov, sprint_fov_kick, blend)
	var smoothing := fov_smoothing
	if _aiming:
		target = aim_fov
		smoothing = aim_smoothing
	_camera.fov = CameraFeel.exp_smoothed(_camera.fov, target, smoothing, delta)

	_apply_stick_look(delta)
	_recoil = move_toward(_recoil, 0.0, recoil_recovery * delta)
	_arm.rotation.x = clampf(_pitch, PITCH_MIN, PITCH_MAX) + _recoil


## Gamepad right-stick look, read as continuous axis state each frame (unlike
## mouse motion, which arrives as discrete events). Shares the yaw/pitch model
## and pitch clamp with mouse-look so both feel identical.
func _apply_stick_look(delta: float) -> void:
	var raw := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	var look := StickInput.look_delta(raw, stick_deadzone, stick_exponent, stick_sensitivity, delta)
	if look == Vector2.ZERO:
		return
	rotation.y -= look.x
	_pitch = clampf(_pitch - look.y, PITCH_MIN, PITCH_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	rotation.y -= motion.relative.x * sensitivity
	_pitch = clampf(_pitch - motion.relative.y * sensitivity, PITCH_MIN, PITCH_MAX)
