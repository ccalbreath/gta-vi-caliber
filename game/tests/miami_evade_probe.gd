extends SceneTree
## "Go cold" probe — proves the wanted level DE-escalates by evasion, not just by
## passive decay. Commits crimes (stars rise, police spawn), then teleports the
## player far away so every officer is recalled out of sight; the
## WantedEvasionController should run its search timer and clear the wanted level
## within a few seconds — far faster than heat decay alone could from max stars,
## so a pass means the evasion path actually fired. Not in check.sh (it needs
## several seconds of frames); run on demand:
##   godot --headless --path game --script res://tests/miami_evade_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 40
const CRIME_COUNT: int = 8
## Frames to let police spawn around the player before we flee.
const SPAWN_FRAMES: int = 160
## After fleeing, the controller's search_duration is 6s (~360 frames); allow a
## margin. Passive decay from ~20 heat could not clear within this window.
const EVADE_FRAMES: int = 1100

var _scene: Node = null
var _player: Node3D = null
var _tracker: Node = null
var _frames: int = 0
var _fled_at: int = 0
var _phase: String = "warmup"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("miami evade probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	match _phase:
		"warmup":
			if _frames >= WARMUP_FRAMES:
				return _commit_crimes()
		"spawning":
			if _frames >= WARMUP_FRAMES + SPAWN_FRAMES:
				return _flee()
		"evading":
			if not _tracker.is_wanted():
				print(
					(
						"miami evade probe: OK (went cold %d frames after fleeing)"
						% (_frames - _fled_at)
					)
				)
				quit(0)
				return true
			if _frames >= _fled_at + EVADE_FRAMES:
				push_error(
					"miami evade probe FAIL :: still wanted after evading (stars never cleared)"
				)
				print("miami evade probe: FAIL")
				quit(1)
				return true
	return false


func _commit_crimes() -> bool:
	_player = get_first_node_in_group("player") as Node3D
	_tracker = get_first_node_in_group("wanted")
	if _player == null or _tracker == null or not _tracker.has_method("report_crime"):
		push_error("miami evade probe FAIL :: missing player or WantedTracker")
		print("miami evade probe: FAIL")
		quit(1)
		return true
	for _i in CRIME_COUNT:
		_tracker.report_crime(true)
	_phase = "spawning"
	return false


func _flee() -> bool:
	if not _tracker.is_wanted():
		push_error("miami evade probe FAIL :: never became wanted after crimes")
		print("miami evade probe: FAIL")
		quit(1)
		return true
	# Break every sightline at once: stop the spawner and remove the officers, so
	# the controller sees nobody and must run its search timer to clear the stars.
	# (Teleporting the player instead is defeated by floating-origin re-centering.)
	var spawner := _scene.find_child("PoliceSpawner", true, false)
	if spawner != null:
		spawner.queue_free()
	for cop in get_nodes_in_group("police"):
		(cop as Node).queue_free()
	_fled_at = _frames
	_phase = "evading"
	return false
