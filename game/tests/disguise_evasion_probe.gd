extends SceneTree
## Runtime probe for the full Disguise -> WantedEvasion loop. Drives
## WantedEvasionController._physics_process manually (engine ticking silenced) for a
## deterministic curve. search_duration = 9s.
##
## 1. SPOTTED: a cop has line of sight -> the controller stamps the player's look
##    (log_sighting), recognition becomes 1.0, and the timer holds (no going cold
##    while watched, even with a disguise on).
## 2. ESCAPE: break sight and change every appearance slot -> recognition drops to
##    0 -> evasion_speedup 3.0 -> one 3s tick drains the whole 9s and goes cold.
## The "let the cops see you, then duck away and change clothes" payoff. Run:
##   godot --headless --path game --script res://tests/disguise_evasion_probe.gd

const WARMUP_FRAMES: int = 3
const SEARCH_SECONDS: float = 9.0
const TICK: float = 3.0
const FAR := Vector3(1000, 0, 0)
const NEW_LOOK := {"outfit": "tracksuit", "mask": "ski_mask", "vehicle": "van", "hair": "blonde"}

var _controller: WantedEvasionController = null
var _tracker: MockTracker = null
var _player: Node3D = null
var _dc: DisguiseController = null
var _cop: Node3D = null
var _frames: int = 0
var _phase: String = "settle"


class MockTracker:
	extends Node
	var wanted: bool = false
	var clears: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func is_wanted() -> bool:
		return wanted

	func clear() -> void:
		wanted = false
		clears += 1


func _initialize() -> void:
	_player = Node3D.new()
	_player.add_to_group("player")
	root.add_child(_player)

	_tracker = MockTracker.new()
	root.add_child(_tracker)

	_dc = DisguiseController.new()
	root.add_child(_dc)

	# A cop in sight range (no world geometry blocks the ray -> seen).
	_cop = Node3D.new()
	_cop.add_to_group("police")
	root.add_child(_cop)
	_cop.position = Vector3(5, 0, 0)

	_controller = WantedEvasionController.new()
	_controller.search_duration = SEARCH_SECONDS
	root.add_child(_controller)


func _process(_delta: float) -> bool:
	_frames += 1
	match _phase:
		"settle":
			if _frames >= WARMUP_FRAMES:
				return _spotted()
		"escape_wait":
			if _frames >= WARMUP_FRAMES:
				return _escape()
	return false


func _spotted() -> bool:
	if _controller == null or _tracker == null or _dc == null:
		return _fail("mock tree did not assemble")
	_controller.set_physics_process(false)
	_tracker.wanted = true

	# Seen by the cop: the controller stamps the description and the timer holds.
	_controller._physics_process(TICK)
	if _tracker.clears != 0 or _controller.is_searching():
		return _fail("went cold / searched while in police sight (clears %d)" % _tracker.clears)
	if not is_equal_approx(_dc.recognition(), 1.0):
		return _fail("log_sighting not fired: recognition %.2f (want 1.0)" % _dc.recognition())

	# Break sight, change every slot, reset the timer, then escape disguised.
	_cop.position = FAR
	_dc.apply_looks(NEW_LOOK)
	_tracker.wanted = false
	_controller._physics_process(0.1)
	_tracker.wanted = true
	_frames = 0
	_phase = "escape_wait"
	return false


func _escape() -> bool:
	if not is_equal_approx(_dc.recognition(), 0.0):
		return _fail("changing every slot did not drop recognition (%.2f)" % _dc.recognition())
	# Unseen + fully disguised: one 3s tick drains the full 9s and goes cold.
	_controller._physics_process(TICK)
	if _tracker.clears != 1:
		return _fail("disguised escape did not go cold 3x faster (clears %d)" % _tracker.clears)
	return _pass()


func _pass() -> bool:
	print(
		"disguise evasion probe: OK (seen=stamped+no escape; ducked away + changed clothes = cold 3x faster)"
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("disguise evasion probe FAIL :: %s" % message)
	print("disguise evasion probe: FAIL — %s" % message)
	quit(1)
	return true
