class_name AnimatedRig
extends Node3D
## Skeletal character rig driven by an AnimationTree state machine.
##
## The player's replacement for the procedural CharacterAnimator (issue #1):
## same animate() input contract fed by Player after move_and_slide, but the
## pose comes from imported CC0 clips (Quaternius Universal Animation
## Library) playing on the Universal Base Character skeleton. Routing from
## locomotion state to state-machine target is pure logic in AnimRouter;
## state classification stays in Locomotion, so both are unit-tested without
## this scene.

## The shared clip library; its skeleton matches the base character's, so the
## imported animations resolve against our Model without retargeting.
const ANIM_LIBRARY_SCENE := "res://assets/characters/universal_animations/UAL1_Standard.glb"

## Blend-space positions for the Move state, matching Locomotion.move_blend's
## axis: 0.0 standing, 0.5 at walk_speed, 1.0 at run_speed.
const BLEND_IDLE := 0.0
const BLEND_WALK := 0.5
const BLEND_JOG := 0.8
const BLEND_SPRINT := 1.0

## Speeds must mirror the Player export values so blend thresholds agree.
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.5
## Yaw turn rate (rad/s) when reorienting toward travel/aim direction.
@export var turn_rate: float = 12.0
## How fast the move blend eases toward its target (1/s).
@export var response_rate: float = 10.0
## Crossfade (s) between ground locomotion and the airborne state.
@export var air_xfade: float = 0.2

var _facing: float = 0.0
var _blend: float = 0.0
var _playback: AnimationNodeStateMachinePlayback = null
# When the owner is the player, face where the weapon aims (not where we
# move) so strafing reads as a third-person shooter. Mirrors CharacterAnimator.
var _aim_facing: bool = false
var _weapon_controller: Node = null
var _phone_raised: bool = false

@onready var _anim_player: AnimationPlayer = $Model/AnimationPlayer
@onready var _tree: AnimationTree = $AnimationTree


func _ready() -> void:
	_facing = rotation.y
	var owner_body := get_parent()
	_aim_facing = owner_body != null and owner_body.is_in_group("player")
	_install_animations()
	_tree.tree_root = _build_state_machine()
	_tree.active = true
	_playback = _tree.get("parameters/playback")
	_playback.start(AnimRouter.STATE_MOVE)


## Drive the rig for one physics frame from the character's current motion.
## Same contract as CharacterAnimator.animate: planar_velocity is world-space
## with y ignored; vertical_velocity tells a rising jump from a fall.
func animate(
	planar_velocity: Vector3,
	on_floor: bool,
	vertical_velocity: float,
	is_climbing: bool,
	delta: float
) -> void:
	var planar_speed := planar_velocity.length()
	var state := Locomotion.state_for(
		planar_speed, on_floor, vertical_velocity, is_climbing, walk_speed, run_speed
	)

	var total_speed := Vector3(planar_velocity.x, vertical_velocity, planar_velocity.z).length()
	var target_blend := AnimRouter.move_blend_value(
		planar_speed, total_speed, is_climbing, walk_speed, run_speed
	)
	_blend = move_toward(_blend, target_blend, response_rate * delta)
	_tree.set("parameters/Move/blend_position", _blend)

	_update_facing(planar_velocity, delta)

	var target := AnimRouter.travel_target(state)
	if _playback.get_current_node() != target:
		_playback.travel(target)


## Same contract as CharacterAnimator.set_phone: Player mirrors the raised /
## pocketed phone here. The UAL Standard tier has no phone-hold clip, so the
## flag is state-only for now — the phone's gameplay rules (sprint and vehicle
## gating) live in Player and keep working; a one-handed holding pose can slot
## in when a suitable clip exists.
func set_phone(raised: bool) -> void:
	_phone_raised = raised


func _update_facing(planar_velocity: Vector3, delta: float) -> void:
	var target := AnimRouter.facing_target(planar_velocity, _aim_yaw())
	if is_nan(target):
		return
	_facing = AnimRouter.rotate_toward_angle(_facing, target, turn_rate * delta)
	rotation.y = _facing


# Aim yaw from the player's WeaponController (NAN while holstered or for
# non-player owners, meaning travel-facing). Mirrors CharacterAnimator.
func _aim_yaw() -> float:
	if not _aim_facing:
		return NAN
	if _weapon_controller == null:
		var found := get_tree().get_nodes_in_group("weapon_controller")
		if found.is_empty():
			return NAN
		_weapon_controller = found[0]
	if _weapon_controller.has_method("facing_override"):
		return _weapon_controller.facing_override()
	return NAN


## Copy the clip library out of the imported animation-library scene into our
## AnimationPlayer. Both scenes share the Armature/Skeleton3D structure and
## bone names, so the tracks drive our skeleton without retargeting.
func _install_animations() -> void:
	var packed: PackedScene = load(ANIM_LIBRARY_SCENE)
	if packed == null:
		push_error("AnimatedRig: cannot load animation library " + ANIM_LIBRARY_SCENE)
		return
	var source := packed.instantiate()
	var players := source.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("AnimatedRig: no AnimationPlayer inside " + ANIM_LIBRARY_SCENE)
		source.free()
		return
	var source_player: AnimationPlayer = players[0]
	var library := source_player.get_animation_library(&"")
	_anim_player.add_animation_library(&"", library)
	source.free()


## Build the locomotion state machine: a Move blend space (idle → walk → jog
## → sprint along Locomotion.move_blend's axis) and an airborne loop, with a
## short crossfade both ways.
func _build_state_machine() -> AnimationNodeStateMachine:
	var machine := AnimationNodeStateMachine.new()

	var move := AnimationNodeBlendSpace1D.new()
	move.add_blend_point(_clip(&"Idle"), BLEND_IDLE)
	move.add_blend_point(_clip(&"Walk"), BLEND_WALK)
	move.add_blend_point(_clip(&"Jog_Fwd"), BLEND_JOG)
	move.add_blend_point(_clip(&"Sprint"), BLEND_SPRINT)
	machine.add_node(AnimRouter.STATE_MOVE, move)

	machine.add_node(AnimRouter.STATE_AIR, _clip(&"Jump"))

	machine.add_transition(AnimRouter.STATE_MOVE, AnimRouter.STATE_AIR, _transition(air_xfade))
	machine.add_transition(AnimRouter.STATE_AIR, AnimRouter.STATE_MOVE, _transition(air_xfade))
	return machine


func _clip(animation_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = animation_name
	return node


func _transition(xfade: float) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = xfade
	return transition
