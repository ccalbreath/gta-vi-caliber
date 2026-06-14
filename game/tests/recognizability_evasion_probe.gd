extends SceneTree
## Runtime probe for the SocialClout -> WantedEvasion closure: a FAMOUS player is recognized
## on sight, so the "go cold" search gives up slower (the price of going viral). Drives
## WantedEvasionController._physics_process manually with no cops in range (always unseen) and
## a MockClout whose recognizability we toggle. search_duration = 8s, MIN_FAME_DRAIN = 0.5:
## an unknown player (recog 0) shakes the cops in one full window; a viral one (recog 1)
## drains at half rate and needs two. Run:
##   godot --headless --path game --script res://tests/recognizability_evasion_probe.gd

const WARMUP_FRAMES: int = 3
const SEARCH: float = 8.0

var _controller: WantedEvasionController = null
var _tracker: MockTracker = null
var _clout: MockClout = null
var _player: Node3D = null
var _frames: int = 0


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


class MockClout:
	extends Node
	var recog: float = 0.0

	func _ready() -> void:
		add_to_group("social_clout")

	func recognizability() -> float:
		return recog


func _initialize() -> void:
	_player = Node3D.new()
	_player.add_to_group("player")
	root.add_child(_player)

	_tracker = MockTracker.new()
	root.add_child(_tracker)

	_clout = MockClout.new()
	root.add_child(_clout)

	_controller = WantedEvasionController.new()
	_controller.search_duration = SEARCH
	root.add_child(_controller)
	_controller.set_physics_process(false)  # only our manual ticks count


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _controller == null or _tracker == null or _clout == null:
		return _fail("mock tree did not assemble")
	var err := _check_fame_slows_cooldown()
	if err != "":
		return _fail(err)
	return _pass()


func _check_fame_slows_cooldown() -> String:
	# Guard the probe's premise so it fails loudly (not vacuously) if the const drifts:
	# fame must SLOW evasion (< 1) without FREEZING it (> 0).
	var drain := WantedEvasionController.MIN_FAME_DRAIN
	if drain <= 0.0 or drain >= 1.0:
		return "probe assumes 0 < MIN_FAME_DRAIN < 1 (got %.2f)" % drain
	# Unknown player: one full unseen window shakes the cops.
	_clout.recog = 0.0
	_tracker.wanted = true
	_controller._physics_process(SEARCH)
	if _tracker.clears != 1:
		return "an unknown player did not go cold after a full window (%d)" % _tracker.clears
	# Famous player: recognized on sight, the SAME window is not enough.
	_clout.recog = 1.0
	_tracker.wanted = true
	_controller._physics_process(SEARCH)
	if _tracker.clears != 1:
		return "a famous player shook the cops as fast as an unknown one (fame ignored)"
	# A second window finishes the half-rate drain.
	_controller._physics_process(SEARCH)
	if _tracker.clears != 2:
		return "a famous player never went cold even after a long search (%d)" % _tracker.clears
	return ""


func _pass() -> bool:
	print(
		(
			"recognizability evasion probe: OK (an unknown player went cold in one window; "
			+ "a viral one was recognized and needed two — fame slows the cool-off)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("recognizability evasion probe FAIL :: %s" % message)
	print("recognizability evasion probe: FAIL — %s" % message)
	quit(1)
	return true
