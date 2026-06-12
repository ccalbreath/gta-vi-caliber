extends SceneTree
## Headed QA capture for the animated player rig (issue #1): boots the
## playable map (miami — the repo's single world scene), simulates
## walk/sprint/jump input, asserts the AnimationTree is in the expected state
## at each phase, and saves screenshots for visual review.
## Needs a renderer — run WITHOUT --headless:
##   godot --path game --script res://tests/player_anim_capture.gd -- [out_dir]
## Screenshots land in out_dir (default /tmp/gta6_player_anim/). Every shot is
## checked for pixel variety so a washed-out or blank render fails loudly
## instead of producing green logs over brown screenshots. Not part of
## check.sh.

## Frames of extra visual settle after the streamers report done, and the
## hard ceiling if they never do (the run then proceeds with a warning).
## The floor exists because the streamers also read idle before their first
## scan ever queues work; empirically the spawn surroundings need ~400
## frames to be in (probed by screenshot, not assumed).
const SETTLE_MIN_FRAMES := 360
const SETTLE_EXTRA_FRAMES := 120
const SETTLE_MAX_FRAMES := 900
const WALK_FRAMES := 100
const SPRINT_FRAMES := 100
## A readable render has hundreds of distinct colors in the middle of the
## frame; a washed or blank viewport has a handful. Only the character
## close-up hard-fails on this: the wide shots can be legitimately fog-flat
## while upstream's brown-wash environment bug (issue #10) is unfixed, so
## they just warn.
const MIN_UNIQUE_COLORS := 50
## Camera distance for the character close-up. Through the inherited heavy
## fog the default 8 m arm fully occludes the character; at ~1.6 m the model
## reads clearly, helped by inspect mode's fill/rim lights.
const INSPECT_ARM_LENGTH := 1.6

var _out_dir := "/tmp/gta6_player_anim"
var _settled_frame := 0

var _frame := 0
var _phase := "boot"
var _phase_started_frame := 0
var _observed: Array[StringName] = []
var _steps := 0
var _steps_at_takeoff := -1
var _steps_at_enter := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	change_scene_to_file("res://scenes/world/miami.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		"boot":
			_phase_boot()
		"walk":
			_phase_walk()
		"sprint":
			_phase_sprint()
		"settle":
			_phase_settle()
		"jump":
			_phase_jump()
		"run_jump":
			_phase_run_jump()
		"front":
			_phase_front()
		"drive":
			_phase_drive()
		"exit_car":
			_phase_exit_car()
	return _phase == "done"


func _phase_boot() -> void:
	# Listen for footsteps from the first frame the player exists, so the
	# idle phase proves silence and the moving phases prove cadence.
	if _player() != null and not _player().is_connected("footstep", _count_step):
		_player().connect("footstep", _count_step)
	if not _streaming_settled():
		if _frame < SETTLE_MAX_FRAMES:
			return
		print("capture: WARNING streamers still busy at frame %d, proceeding" % _frame)
	if _settled_frame == 0:
		_settled_frame = _frame
		print("capture: streaming settled at frame %d" % _frame)
	if _frame < _settled_frame + SETTLE_EXTRA_FRAMES:
		return
	if _player() == null:
		_failures.append("no node in 'player' group after world boot")
		_finish()
		return
	_assert_player_framed()
	_shot("01_idle")
	_expect_state(AnimRouter.STATE_MOVE, 0.0, 0.1, "idle")
	if _steps > 0:
		_failures.append("footsteps fired while standing idle (%d)" % _steps)
	_face_clearest_direction()
	Input.action_press("move_forward")
	_next("walk")


## All districts resident and no tile loads in flight. Residency at a fixed
## frame count is nondeterministic (one run has a facade 25 m from spawn,
## the next has 80 m of nothing), so the capture waits for the streamers
## themselves before trusting the world.
func _streaming_settled() -> bool:
	if _player() == null or _frame < SETTLE_MIN_FRAMES:
		return false
	var districts := get_first_node_in_group("district_streamer")
	if districts != null:
		var resident: int = districts.call("resident_names").size()
		if resident < int(districts.call("district_count")):
			return false
	var tiles := get_first_node_in_group("tile_streamer")
	if tiles != null:
		var stats: Dictionary = tiles.call("stats")
		if int(stats["loading"]) > 0:
			return false
	return true


## Movement is camera-relative, so point the camera down the longest clear
## line from the spawn before the walk/sprint/jump phases. Once the city's
## colliders are streamed in (which the long settle guarantees), marching
## blindly camera-forward walks the player into a facade mid-phase and the
## sprint/jump assertions fail on a stationary character.
func _face_clearest_direction() -> void:
	var space := _player().get_world_3d().direct_space_state
	var origin := _player().global_position + Vector3.UP
	var best_yaw := 0.0
	var best_distance := 0.0
	for i in 16:
		var yaw := TAU * float(i) / 16.0
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 80.0)
		query.exclude = [(_player() as CharacterBody3D).get_rid()]
		var hit := space.intersect_ray(query)
		var distance := 80.0 if hit.is_empty() else origin.distance_to(hit.position)
		if distance > best_distance:
			best_distance = distance
			best_yaw = yaw
	var camera_rig := _player().get_node("CameraRig") as Node3D
	camera_rig.rotation.y = best_yaw
	print("capture: facing yaw %.2f rad (%.0f m clear)" % [best_yaw, best_distance])


func _count_step(_surface: String, _is_left: bool) -> void:
	_steps += 1


func _phase_walk() -> void:
	if _frame < WALK_FRAMES:
		return
	_shot("02_walk")
	_expect_state(AnimRouter.STATE_MOVE, 0.5, 0.1, "walk")
	if _steps == 0:
		_failures.append("no footsteps while walking")
	print("capture: %d footsteps during walk phase" % _steps)
	Input.action_press("sprint")
	_next("sprint")


func _phase_sprint() -> void:
	if _frame < SPRINT_FRAMES:
		return
	_shot("03_sprint")
	_expect_state(AnimRouter.STATE_MOVE, 1.0, 0.1, "sprint")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_next("settle")


func _phase_settle() -> void:
	# Let the character brake to idle so the next jump is a standing jump.
	if _frame < 45:
		return
	Input.action_press("jump")
	_observed.clear()
	_next("jump")


## Standing jump: the full three-phase chain must play — JumpStart one-shot,
## Air loop, then the Land absorb (planar speed ~0 is under land_skip_speed).
func _phase_jump() -> void:
	if _frame == 5:
		Input.action_release("jump")
	_record_states("04_jump")
	if _frame > 600:
		_failures.append("standing jump never returned to Move (saw %s)" % str(_observed))
		_finish()
		return
	if _frame < 30 or not _grounded_in_move():
		return
	for expected: StringName in [
		AnimRouter.STATE_JUMP_START, AnimRouter.STATE_AIR, AnimRouter.STATE_LAND
	]:
		if not _observed.has(expected):
			_failures.append("standing jump skipped '%s' (saw %s)" % [expected, str(_observed)])
	print("capture: standing jump chain = %s" % str(_observed))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	_observed.clear()
	_next("run_jump")


## Sprinting jump: landing above land_skip_speed must skip the Land absorb
## and roll straight back into locomotion.
func _phase_run_jump() -> void:
	if _frame == 60:
		Input.action_press("jump")
	if _frame == 65:
		Input.action_release("jump")
	if _frame <= 60:
		return
	_record_states("")
	if _frame > 600:
		_failures.append("running jump never returned to Move (saw %s)" % str(_observed))
		_finish()
		return
	if not _grounded_in_move() or _observed.is_empty():
		return
	if not _observed.has(AnimRouter.STATE_AIR):
		_failures.append("running jump never reached Air (saw %s)" % str(_observed))
	if _observed.has(AnimRouter.STATE_LAND):
		_failures.append("running landing should skip Land (saw %s)" % str(_observed))
	print("capture: running jump chain = %s" % str(_observed))
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_next("front")


## Append each state-machine node as it becomes current; screenshot the
## airborne phases of the standing jump the first time each appears. Also
## police that no footstep fires while the body is off the ground.
func _record_states(shot_prefix: String) -> void:
	if not (_player() as CharacterBody3D).is_on_floor():
		if _steps_at_takeoff < 0:
			_steps_at_takeoff = _steps
		elif _steps != _steps_at_takeoff:
			_failures.append("footsteps fired mid-air")
			_steps_at_takeoff = _steps
	else:
		_steps_at_takeoff = -1
	var current := _current_state()
	if current == AnimRouter.STATE_MOVE:
		return
	if _observed.is_empty() or _observed[_observed.size() - 1] != current:
		_observed.append(current)
		if not shot_prefix.is_empty():
			_shot("%s_%s" % [shot_prefix, current])


func _grounded_in_move() -> bool:
	return (
		(_player() as CharacterBody3D).is_on_floor() and _current_state() == AnimRouter.STATE_MOVE
	)


func _phase_front() -> void:
	# Wait for the actual landing (frame rate varies, so counting frames
	# against the ~1 s jump arc is unreliable), then use the camera's own
	# character-inspection mode (front swing + fill/rim lights) with the arm
	# pulled in close, so the model itself is reviewable even through the
	# inherited heavy fog (issue #10).
	if _phase_started_frame == 0:
		if (_player() as CharacterBody3D).is_on_floor():
			_phase_started_frame = _frame
			_camera().call("set_character_inspect", true)
			_arm().spring_length = INSPECT_ARM_LENGTH
		elif _frame > 600:
			_failures.append("player never landed after jump")
			_finish()
		return
	if _frame < _phase_started_frame + 60:
		return
	_assert_player_framed()
	_shot("05_front_closeup", true)
	_expect_state(AnimRouter.STATE_MOVE, 0.0, 0.15, "front idle")
	_camera().call("set_character_inspect", false)
	_arm().spring_length = 8.0
	_next("drive")


func _camera() -> Node3D:
	return _player().get_node("CameraRig") as Node3D


func _arm() -> SpringArm3D:
	return _player().get_node("CameraRig/SpringArm") as SpringArm3D


## Driving regression check: the rig's AnimationTree stays active while the
## hidden player rides a vehicle, so no foot plants may leak through as
## footstep audio for the whole drive.
func _phase_drive() -> void:
	if _frame == 1:
		var car := _car()
		if car == null:
			_failures.append("no vehicle in the world for the drive check")
			_finish()
			return
		_player().global_position = car.global_position + Vector3(2.0, 0.2, 0.0)
	if _frame == 5:
		# Approach in motion: entering with a non-zero move blend is exactly
		# the case where a frozen rig would keep firing plants from the car.
		Input.action_press("move_forward")
	if _frame == 20:
		_press_action_event("interact")
	if _frame == 60:
		if _player().get("_vehicle") == null:
			_failures.append("interact near the car did not enter it")
			_finish()
			return
		# Baseline after entry: the move blend needs a beat to decay to idle.
		_steps_at_enter = _steps
	if _frame < 240:
		return
	Input.action_release("move_forward")
	if _steps != _steps_at_enter:
		_failures.append("footsteps fired while driving (%d)" % (_steps - _steps_at_enter))
	print("capture: drive phase silent (%d steps before, %d after)" % [_steps_at_enter, _steps])
	_press_action_event("interact")
	_next("exit_car")


func _phase_exit_car() -> void:
	if _frame < 30:
		return
	if _player().get("_vehicle") != null:
		_failures.append("interact while driving did not exit the car")
	_finish()


func _car() -> Node3D:
	for node in get_nodes_in_group("vehicles"):
		if node is VehicleBody3D and node.name == "Car":
			return node
	return null


## Route a press through the event pipeline so _unhandled_input handlers see it.
func _press_action_event(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


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


## The active camera must be the player's own (a descendant of the player
## node) and the player must project inside the viewport, so the screenshots
## are guaranteed to be of OUR character in third person, not a detached or
## stolen camera.
func _assert_player_framed() -> void:
	var cam := root.get_camera_3d()
	if cam == null:
		_failures.append("no current Camera3D after world boot")
		return
	var node: Node = cam
	while node != null and node != _player():
		node = node.get_parent()
	if node == null:
		_failures.append("current camera %s is not under the player" % cam.get_path())
	var chest := _player().global_position + Vector3.UP
	if cam.is_position_behind(chest):
		_failures.append("player is behind the current camera")
		return
	var screen := cam.unproject_position(chest)
	var vp := root.get_visible_rect().size
	if screen.x < 0.0 or screen.y < 0.0 or screen.x > vp.x or screen.y > vp.y:
		_failures.append("player projects off-screen at %s (viewport %s)" % [screen, vp])
	else:
		print("capture: player framed at %s in %s" % [screen, vp])


func _shot(name: String, must_have_detail: bool = false) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	img.save_png(path)
	var unique := _center_unique_colors(img)
	if unique < MIN_UNIQUE_COLORS:
		if must_have_detail:
			_failures.append(
				(
					"%s.png is near-uniform (%d unique center colors) — character not rendering"
					% [name, unique]
				)
			)
		else:
			print(
				(
					"capture: WARNING %s.png is near-uniform (%d colors) — fog wash, see issue #10"
					% [name, unique]
				)
			)
	print("capture: saved %s (%d unique center colors)" % [path, unique])


## Distinct colors in the center half of the frame (sampled on a grid). The
## HUD hugs the edges, so this looks at the 3D view itself.
func _center_unique_colors(img: Image) -> int:
	var size := img.get_size()
	var colors := {}
	for y in range(size.y / 4, 3 * size.y / 4, 8):
		for x in range(size.x / 4, 3 * size.x / 4, 8):
			var c := img.get_pixel(x, y)
			colors[Color8(c.r8, c.g8, c.b8)] = true
	return colors.size()


func _finish() -> void:
	if _failures.is_empty():
		print("player anim capture: OK")
	else:
		for f in _failures:
			push_error("player anim capture FAIL: " + f)
	quit(0 if _failures.is_empty() else 1)
	_phase = "done"
