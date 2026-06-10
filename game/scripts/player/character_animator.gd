class_name CharacterAnimator
extends Node3D
## Procedural greybox animator.
##
## Drives a blocky humanoid rig (hips, two arms, two legs) entirely from
## Locomotion math — no imported skeletal clips yet. The player feeds it raw
## motion each physics frame and this turns it into: facing toward travel,
## counter-swinging limbs locked to distance, a torso bob on each foot plant, a
## lean into acceleration, and a static air pose while jumping/falling. When
## real animation clips land (M1), this same input contract can drive an
## AnimationTree instead and the rig nodes become bones.

# Air pose: a relaxed running-in-air shape, crossfaded in while airborne.
const AIR_SHOULDER: float = -0.5
const AIR_HIP_LEAD: float = -0.35
const AIR_HIP_TRAIL: float = 0.25

## Speeds must mirror the Player export values so blend/state thresholds agree.
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.5
## Peak swing angles (radians) at full run; scaled down by the move blend.
@export var leg_amplitude: float = 0.7
@export var arm_amplitude: float = 0.5
## Torso vertical bob (metres) at full run.
@export var bob_amplitude: float = 0.07
## Maximum forward/back lean (radians) from acceleration.
@export var max_lean: float = 0.22
## Acceleration (m/s²) that produces a full-magnitude lean.
@export var accel_reference: float = 30.0
## Yaw turn rate (rad/s) when reorienting toward the travel direction.
@export var turn_rate: float = 12.0
## How fast swing amplitude and lean ease toward their targets (1/s).
@export var response_rate: float = 10.0
## How fast the air pose crossfades in/out (1/s).
@export var air_rate: float = 8.0

var _phase: float = 0.0
var _facing: float = 0.0
var _blend: float = 0.0
var _lean: float = 0.0
var _air: float = 0.0
var _hips_rest_y: float = 0.0
var _prev_speed: float = 0.0

@onready var _hips: Node3D = $Hips
@onready var _hip_l: Node3D = $Hips/HipL
@onready var _hip_r: Node3D = $Hips/HipR
@onready var _shoulder_l: Node3D = $Hips/ShoulderL
@onready var _shoulder_r: Node3D = $Hips/ShoulderR


func _ready() -> void:
	_hips_rest_y = _hips.position.y
	_facing = rotation.y


## Drive the rig for one physics frame from the character's current motion.
## planar_velocity is world-space with y ignored; vertical_velocity is the
## signed y component used to tell a rising jump from a fall.
func animate(
	planar_velocity: Vector3,
	on_floor: bool,
	vertical_velocity: float,
	is_climbing: bool,
	delta: float
) -> void:
	var planar_speed: float = planar_velocity.length()
	var state: Locomotion.State = Locomotion.state_for(
		planar_speed, on_floor, vertical_velocity, is_climbing, walk_speed, run_speed
	)

	_update_facing(planar_velocity, planar_speed, delta)

	var accel: float = (planar_speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = planar_speed

	var target_blend: float = Locomotion.move_blend(planar_speed, walk_speed, run_speed)
	_blend = move_toward(_blend, target_blend, response_rate * delta)
	_lean = lerpf(_lean, Locomotion.lean_angle(accel, accel_reference, max_lean), _ease(delta))
	_air = move_toward(_air, 1.0 if not on_floor else 0.0, air_rate * delta)

	if planar_speed > Locomotion.IDLE_SPEED_EPSILON:
		_phase = Locomotion.advance_phase(_phase, planar_speed, delta)

	_apply_limbs()
	_hips.position.y = _hips_rest_y + Locomotion.vertical_bob(_phase, bob_amplitude * _blend)
	_hips.rotation.x = _lean


func _update_facing(planar_velocity: Vector3, planar_speed: float, delta: float) -> void:
	if planar_speed > Locomotion.IDLE_SPEED_EPSILON:
		var target: float = atan2(planar_velocity.x, planar_velocity.z)
		_facing = _rotate_toward_angle(_facing, target, turn_rate * delta)
	rotation.y = _facing


func _apply_limbs() -> void:
	var leg_amp: float = leg_amplitude * _blend
	var arm_amp: float = arm_amplitude * _blend
	_hip_l.rotation.x = lerpf(Locomotion.limb_swing(_phase, leg_amp), AIR_HIP_LEAD, _air)
	_hip_r.rotation.x = lerpf(Locomotion.limb_swing(_phase + PI, leg_amp), AIR_HIP_TRAIL, _air)
	# Arms counter-swing the legs (offset by PI) and tuck up in the air pose.
	_shoulder_l.rotation.x = lerpf(Locomotion.limb_swing(_phase + PI, arm_amp), AIR_SHOULDER, _air)
	_shoulder_r.rotation.x = lerpf(Locomotion.limb_swing(_phase, arm_amp), AIR_SHOULDER, _air)


# Critically-damped-ish easing factor, clamped so a long frame can't overshoot.
func _ease(delta: float) -> float:
	return clampf(response_rate * delta, 0.0, 1.0)


# Step an angle toward a target along the shortest arc, capped at max_step.
static func _rotate_toward_angle(current: float, target: float, max_step: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	return current + clampf(diff, -max_step, max_step)
