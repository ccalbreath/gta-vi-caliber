extends SceneTree
## Scene-free probe for DisguiseTracker feeding WantedEvasionController.
##
## Once police have a description and the player changes enough slots, the wanted
## search timer should consume delta faster. This keeps the wardrobe/disguise work
## connected to the actual "go cold" loop.
## Run headless:
##   godot --headless --path game --script res://tests/disguise_evasion_probe.gd

const SETTLE_FRAMES: int = 3
const SEARCH_DURATION: float = 4.0
const DISGUISED_DELTA: float = 1.5
const DISGUISE_TRACKER_SCRIPT := preload("res://scripts/systems/disguise_tracker.gd")

var _wanted: MockWanted = null
var _tracker: Node = null
var _controller: WantedEvasionController = null
var _frames: int = 0


class MockWanted:
	extends Node
	var wanted: bool = true
	var clears: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func is_wanted() -> bool:
		return wanted

	func clear() -> void:
		wanted = false
		clears += 1


func _initialize() -> void:
	var player := Node3D.new()
	player.add_to_group("player")
	root.add_child(player)
	_wanted = MockWanted.new()
	root.add_child(_wanted)
	_tracker = DISGUISE_TRACKER_SCRIPT.new()
	root.add_child(_tracker)
	_controller = WantedEvasionController.new()
	_controller.search_duration = SEARCH_DURATION
	root.add_child(_controller)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	return _run()


func _run() -> bool:
	_tracker.log_sighting()
	for slot: Variant in _tracker.disguise.slots():
		_tracker.set_appearance(String(slot), "changed_%s" % String(slot))
	if _tracker.evasion_speedup() < 2.9:
		return _fail("disguise speedup too low after full appearance change")
	_controller._physics_process(DISGUISED_DELTA)
	if _wanted.clears != 1:
		return _fail("wanted did not clear with disguised search speedup")
	return _pass()


func _pass() -> bool:
	print("disguise evasion probe: OK (disguise sped up wanted clear)")
	quit(0)
	return true


func _fail(reason: String) -> bool:
	push_error("disguise evasion probe FAIL: %s" % reason)
	quit(1)
	return true
