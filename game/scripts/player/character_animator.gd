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

# One-handed phone-to-ear pose for the right arm while the phone is raised:
# the shoulder swings the arm up and rolls the hand in toward the head.
const PHONE_SHOULDER_PITCH: float = -2.35
const PHONE_SHOULDER_ROLL: float = 0.55

## Speeds must mirror the Player export values so blend/state thresholds agree.
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.5
## Peak swing angles (radians) at full run; scaled down by the move blend.
@export var leg_amplitude: float = 0.7
@export var arm_amplitude: float = 0.5
## Torso vertical bob (metres) at full run.
@export var bob_amplitude: float = 0.07
## Lateral pelvis travel (metres) at full run: tiny weight shift over each foot.
@export var sway_amplitude: float = 0.032
## Pelvis/shoulder roll (radians) at full run for athletic counter-motion.
@export var roll_amplitude: float = 0.07
## Upper-body yaw twist (radians) at full run; shoulders counter the stepping
## leg while pelvis/head absorb a smaller amount so the rig reads less rigid.
@export var torso_twist_amplitude: float = 0.075
@export var pelvis_twist_compensation: float = 0.35
@export var head_twist_compensation: float = 0.22
## Subtle head stabilization layered over the body motion so Mara's face does
## not look bolted to the torso while running.
@export var head_pitch_amplitude: float = 0.026
@export var head_roll_amplitude: float = 0.035
@export var head_lean_compensation: float = 0.28
## Extra stride detail for a premium third-person read: shoulders rise
## asymmetrically with arm drive and the chest compresses on foot load.
@export var shoulder_lift_amplitude: float = 0.035
@export var chest_stride_compression: float = 0.032
## Idle life layered on top of the still pose: breathing, neck compensation,
## and a slow hip weight shift while grounded.
@export var idle_breath_amplitude: float = 0.018
@export var idle_sway_amplitude: float = 0.014
@export var idle_head_pitch_amplitude: float = 0.014
## Maximum forward/back lean (radians) from acceleration.
@export var max_lean: float = 0.22
## Acceleration (m/s²) that produces a full-magnitude lean.
@export var accel_reference: float = 30.0
## Yaw turn rate (rad/s) when reorienting toward the travel direction.
@export var turn_rate: float = 12.0
## Roll into sharp facing changes so turning carries body momentum.
@export var max_turn_lean: float = 0.08
@export var turn_lean_reference: float = 8.0
## How fast swing amplitude and lean ease toward their targets (1/s).
@export var response_rate: float = 10.0
## How fast the air pose crossfades in/out (1/s).
@export var air_rate: float = 8.0
## Hip dip on floor contact after a fall, then eased back out.
@export var max_landing_compression: float = 0.09
@export var landing_velocity_reference: float = 12.0
@export var landing_recovery_rate: float = 5.5
## How fast the phone-holding pose eases in/out (1/s).
@export var phone_pose_rate: float = 9.0

var _phase: float = 0.0
var _facing: float = 0.0
var _blend: float = 0.0
var _lean: float = 0.0
var _sway: float = 0.0
var _roll: float = 0.0
var _turn_lean: float = 0.0
var _idle_time: float = 0.0
var _air: float = 0.0
var _landing_compression: float = 0.0
var _was_on_floor: bool = true
var _last_vertical_velocity: float = 0.0
var _phone: float = 0.0
var _phone_target: float = 0.0
var _hips_rest_y: float = 0.0
var _hips_rest_x: float = 0.0
var _prev_speed: float = 0.0
var _proxy_torso_mount: Node3D = null
var _proxy_pelvis_mount: Node3D = null
var _proxy_head_mount: Node3D = null
# When the owner is the player, face where the weapon aims (not where we move)
# so strafing reads as a third-person shooter. NPCs keep travel-facing.
var _aim_facing: bool = false
var _weapon_controller: Node = null

@onready var _hips: Node3D = $Hips
@onready var _pelvis: Node3D = $Hips/Pelvis
@onready var _torso: Node3D = $Hips/Torso
@onready var _hip_l: Node3D = $Hips/HipL
@onready var _hip_r: Node3D = $Hips/HipR
@onready var _shoulder_l: Node3D = $Hips/ShoulderL
@onready var _shoulder_r: Node3D = $Hips/ShoulderR
@onready var _head: Node3D = $Hips/Head


func _ready() -> void:
	_hips_rest_y = _hips.position.y
	_hips_rest_x = _hips.position.x
	_facing = rotation.y
	var owner_body := get_parent()
	_aim_facing = owner_body != null and owner_body.is_in_group("player")
	_proxy_torso_mount = _ensure_proxy_mount("MaraTorsoMount")
	_proxy_pelvis_mount = _ensure_proxy_mount("MaraPelvisMount")
	_proxy_head_mount = _ensure_proxy_mount("MaraHeadMount")
	_sync_imported_proxy_mounts()


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

	var facing_before := _facing
	_update_facing(planar_velocity, planar_speed, delta)
	var turn_velocity := wrapf(_facing - facing_before, -PI, PI) / maxf(delta, 0.0001)

	var accel: float = (planar_speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = planar_speed

	var target_blend: float = Locomotion.move_blend(planar_speed, walk_speed, run_speed)
	_blend = move_toward(_blend, target_blend, response_rate * delta)
	_lean = lerpf(_lean, Locomotion.lean_angle(accel, accel_reference, max_lean), _ease(delta))
	var grounded_blend := _blend if on_floor else 0.0
	_sway = lerpf(
		_sway, Locomotion.lateral_sway(_phase, sway_amplitude * grounded_blend), _ease(delta)
	)
	_roll = lerpf(
		_roll, Locomotion.pelvis_roll(_phase, roll_amplitude * grounded_blend), _ease(delta)
	)
	_turn_lean = lerpf(
		_turn_lean,
		Locomotion.turn_lean(turn_velocity, turn_lean_reference, max_turn_lean) * grounded_blend,
		_ease(delta)
	)
	_landing_compression = move_toward(_landing_compression, 0.0, landing_recovery_rate * delta)
	if on_floor and not _was_on_floor:
		_landing_compression = maxf(
			_landing_compression,
			Locomotion.landing_compression(
				_last_vertical_velocity, landing_velocity_reference, max_landing_compression
			)
		)
	_was_on_floor = on_floor
	_last_vertical_velocity = vertical_velocity
	_air = move_toward(_air, 1.0 if not on_floor else 0.0, air_rate * delta)
	_phone = move_toward(_phone, _phone_target, phone_pose_rate * delta)
	if on_floor:
		_idle_time += delta

	if planar_speed > Locomotion.IDLE_SPEED_EPSILON:
		_phase = Locomotion.advance_phase(_phase, planar_speed, delta)

	_apply_limbs()
	_apply_secondary_motion()
	_apply_phone_pose()
	var idle_strength := (1.0 - _blend) if on_floor else 0.0
	var idle_breath := Locomotion.idle_breath(_idle_time, idle_breath_amplitude * idle_strength)
	var idle_sway := Locomotion.idle_weight_shift(_idle_time, idle_sway_amplitude * idle_strength)
	_hips.position.x = _hips_rest_x + _sway + idle_sway
	_hips.position.y = (
		_hips_rest_y
		+ Locomotion.vertical_bob(_phase, bob_amplitude * _blend)
		+ idle_breath
		- _landing_compression
	)
	_hips.rotation.x = _lean
	_hips.rotation.z = _roll + _turn_lean
	_sync_imported_proxy_mounts()


## Raise (true) or lower (false) the one-handed phone-holding pose; eased in
## animate() and blended over the right arm after the walk swing is applied.
func set_phone(raised: bool) -> void:
	_phone_target = 1.0 if raised else 0.0


# Blend the right arm from its swing pose toward holding a phone to the ear.
# Runs after _apply_limbs so it overrides that frame's shoulder swing.
func _apply_phone_pose() -> void:
	_shoulder_r.rotation.x = lerpf(_shoulder_r.rotation.x, PHONE_SHOULDER_PITCH, _phone)
	_shoulder_r.rotation.z = PHONE_SHOULDER_ROLL * _phone


func _apply_secondary_motion() -> void:
	var shoulder_roll := Locomotion.shoulder_counter_roll(_phase, roll_amplitude * 0.65 * _blend)
	var twist := Locomotion.torso_twist(_phase, torso_twist_amplitude * _blend)
	var turn_shoulder_roll := _turn_lean * 0.35
	var lift := shoulder_lift_amplitude * _blend
	var left_lift := maxf(0.0, sin(_phase + PI)) * lift
	var right_lift := maxf(0.0, sin(_phase)) * lift
	var chest_load := absf(sin(_phase)) * chest_stride_compression * _blend
	_shoulder_l.rotation.z = shoulder_roll + turn_shoulder_roll
	_shoulder_r.rotation.z = -shoulder_roll + turn_shoulder_roll
	_shoulder_l.position.y = 0.6 - _landing_compression * 0.18 + left_lift
	_shoulder_r.position.y = 0.6 - _landing_compression * 0.18 + right_lift
	_torso.rotation.x = -chest_load
	_shoulder_l.rotation.y = twist
	_shoulder_r.rotation.y = twist
	_torso.rotation.y = twist
	_pelvis.rotation.y = -twist * pelvis_twist_compensation
	var head_pitch := Locomotion.head_step_pitch(_phase, head_pitch_amplitude * _blend)
	var head_roll := Locomotion.head_counter_roll(_phase, head_roll_amplitude * _blend)
	var idle_strength := 1.0 - _blend
	var idle_head_pitch := Locomotion.idle_head_pitch(
		_idle_time, idle_head_pitch_amplitude * idle_strength
	)
	_head.rotation.x = head_pitch + idle_head_pitch - _lean * head_lean_compensation
	_head.rotation.y = -twist * head_twist_compensation
	_head.rotation.z = head_roll - (_roll + _turn_lean) * 0.45


func _ensure_proxy_mount(node_name: String) -> Node3D:
	var mount := _hips.get_node_or_null(node_name) as Node3D
	if mount == null:
		mount = Node3D.new()
		mount.name = node_name
		_hips.add_child(mount)
	return mount


func _sync_imported_proxy_mounts() -> void:
	if _proxy_torso_mount != null:
		_proxy_torso_mount.position = _torso.position
		_proxy_torso_mount.rotation = _torso.rotation
	if _proxy_pelvis_mount != null:
		_proxy_pelvis_mount.position = _pelvis.position
		_proxy_pelvis_mount.rotation = _pelvis.rotation
	if _proxy_head_mount != null:
		_proxy_head_mount.position = _head.position
		_proxy_head_mount.rotation = _head.rotation


func _update_facing(planar_velocity: Vector3, planar_speed: float, delta: float) -> void:
	var target: float = _facing
	var has_target: bool = false
	# While armed, face the aim direction so the character strafes around it.
	if _aim_facing:
		var aim: float = _aim_yaw()
		if not is_nan(aim):
			target = aim
			has_target = true
	if not has_target and planar_speed > Locomotion.IDLE_SPEED_EPSILON:
		# Face the travel direction. The rig's forward (its face/chest) is local -Z
		# (Godot/Blender convention), so point -Z along velocity — negating both
		# components, NOT atan2(x, z), which would aim the back of the head forward
		# and make the character moonwalk.
		target = atan2(-planar_velocity.x, -planar_velocity.z)
		has_target = true
	if has_target:
		_facing = _rotate_toward_angle(_facing, target, turn_rate * delta)
	rotation.y = _facing


# Aim yaw from the player's WeaponController (NAN while holstered → travel-facing).
func _aim_yaw() -> float:
	if _weapon_controller == null:
		var found := get_tree().get_nodes_in_group("weapon_controller")
		if found.is_empty():
			return NAN
		_weapon_controller = found[0]
	if _weapon_controller.has_method("facing_override"):
		return _weapon_controller.facing_override()
	return NAN


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
