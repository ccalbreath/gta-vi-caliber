extends SceneTree
## Headed QA capture for the animated player rig (issue #1): boots the
## sandbox, simulates walk/sprint/jump input, asserts the AnimationTree is in
## the expected state at each phase, and saves screenshots for visual review.
## Needs a renderer — run WITHOUT --headless:
##   godot --path game --script res://tests/player_anim_capture.gd
## Screenshots land in /tmp/gta6_player_anim/. Not part of check.sh.

const OUT_DIR := "/tmp/gta6_player_anim"
const SETTLE_FRAMES := 90
const WALK_FRAMES := 100
const SPRINT_FRAMES := 100

var _frame := 0
var _phase := "boot"
var _phase_started_frame := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	change_scene_to_file("res://scenes/world/sandbox.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		"boot":
			_phase_boot()
		"walk":
			_phase_walk()
		"sprint":
			_phase_sprint()
		"jump":
			_phase_jump()
		"front":
			_phase_front()
	return _phase == "done"


func _phase_boot() -> void:
	if _frame < SETTLE_FRAMES:
		return
	if _player() == null:
		_failures.append("no node in 'player' group after sandbox boot")
		_finish()
		return
	_shot("01_idle")
	_expect_state(AnimRouter.STATE_MOVE, 0.0, 0.1, "idle")
	Input.action_press("move_forward")
	_next("walk")


func _phase_walk() -> void:
	if _frame < WALK_FRAMES:
		return
	_shot("02_walk")
	_expect_state(AnimRouter.STATE_MOVE, 0.5, 0.1, "walk")
	Input.action_press("sprint")
	_next("sprint")


func _phase_sprint() -> void:
	if _frame < SPRINT_FRAMES:
		return
	_shot("03_sprint")
	_expect_state(AnimRouter.STATE_MOVE, 1.0, 0.1, "sprint")
	Input.action_press("jump")
	_next("jump")


func _phase_jump() -> void:
	if _frame == 5:
		Input.action_release("jump")
	# Capture near the top of the arc: wait until the body is actually
	# airborne, then a short beat more, so the shot isn't the launch frame.
	if _phase_started_frame == 0:
		if not (_player() as CharacterBody3D).is_on_floor():
			_phase_started_frame = _frame
		elif _frame > 300:
			_failures.append("player never left the ground after jump press")
			_finish()
		return
	if _frame < _phase_started_frame + 25:
		return
	_shot("04_airborne")
	var current := _current_state()
	if current != AnimRouter.STATE_AIR:
		_failures.append("expected Air state mid-jump, got '%s'" % current)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_next("front")


func _phase_front() -> void:
	# Wait for the actual landing (frame rate varies, so counting frames
	# against the ~1 s jump arc is unreliable), then swing the camera around
	# to face the character so the model itself can be reviewed.
	if _phase_started_frame == 0:
		if (_player() as CharacterBody3D).is_on_floor():
			_phase_started_frame = _frame
			var camera_rig := _player().get_node("CameraRig") as Node3D
			camera_rig.rotation.y = PI
		elif _frame > 600:
			_failures.append("player never landed after jump")
			_finish()
		return
	if _frame < _phase_started_frame + 45:
		return
	_shot("05_front_idle")
	_expect_state(AnimRouter.STATE_MOVE, 0.0, 0.15, "front idle")
	_finish()


func _expect_state(node: StringName, blend: float, tolerance: float, label: String) -> void:
	var current := _current_state()
	if current != node:
		_failures.append("%s: expected state '%s', got '%s'" % [label, node, current])
	var actual_blend := _move_blend()
	if absf(actual_blend - blend) > tolerance:
		_failures.append("%s: expected blend ~%.2f, got %.2f" % [label, blend, actual_blend])
	print("capture: %s -> state=%s blend=%.2f" % [label, current, actual_blend])


func _current_state() -> StringName:
	var playback: AnimationNodeStateMachinePlayback = _tree().get("parameters/playback")
	return playback.get_current_node()


func _move_blend() -> float:
	return _tree().get("parameters/Move/blend_position")


func _tree() -> AnimationTree:
	return _player().get_node("Rig/AnimationTree") as AnimationTree


func _player() -> Node3D:
	return get_first_node_in_group("player") as Node3D


func _next(phase: String) -> void:
	_phase = phase
	_frame = 0
	_phase_started_frame = 0


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	img.save_png(path)
	print("capture: saved %s" % path)


func _finish() -> void:
	if _failures.is_empty():
		print("player anim capture: OK")
	else:
		for f in _failures:
			push_error("player anim capture FAIL: " + f)
	quit(0 if _failures.is_empty() else 1)
	_phase = "done"
