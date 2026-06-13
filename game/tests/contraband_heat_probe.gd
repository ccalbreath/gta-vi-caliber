extends SceneTree
## Runtime wiring probe for the contraband bust-risk -> police heat seam: carrying
## contraband accrues suspicion at ContrabandMarket.bust_risk(), and crossing the
## threshold reports a crime to the live wanted tracker. Drives _process manually
## (engine ticking silenced) for a deterministic curve. Run:
##   godot --headless --path game --script res://tests/contraband_heat_probe.gd

const WARMUP_FRAMES: int = 3
const SECONDS_PER_BUST: float = 10.0
const BASE_RISK: float = 0.0
const LOAD: int = 10
# bust_risk(LOAD, BASE_RISK) over one full SECONDS_PER_BUST tick (model: total*0.05).
const EXPECTED_EXPOSURE: float = float(LOAD) * 0.05

var _ctl: ContrabandController = null
var _wanted: MockWanted = null
var _frames: int = 0
var _busted_count: int = 0


class MockWanted:
	extends Node
	var crime_count: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		crime_count += 1


func _initialize() -> void:
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	_ctl = ContrabandController.new()
	_ctl.base_bust_risk = BASE_RISK
	_ctl.seconds_per_bust = SECONDS_PER_BUST
	_ctl.busted.connect(_on_busted)
	root.add_child(_ctl)


func _on_busted(_carried: int) -> void:
	_busted_count += 1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _wanted == null:
		return _fail("mock tree did not assemble")
	_ctl.set_process(false)  # drive the risk clock manually

	# Empty-handed: plenty of time passes, no bust.
	_ctl._process(SECONDS_PER_BUST * 3.0)
	if _wanted.crime_count != 0 or _ctl.bust_exposure() != 0.0:
		return _fail("a clean player drew police heat (crimes %d)" % _wanted.crime_count)

	# Load up: one tick accrues part of the meter, not yet busted.
	_ctl.market().carry("product", LOAD)
	_ctl._process(SECONDS_PER_BUST)
	if _wanted.crime_count != 0 or not is_equal_approx(_ctl.bust_exposure(), EXPECTED_EXPOSURE):
		return _fail("partial load busted too early (exposure %.2f)" % _ctl.bust_exposure())

	return _run_bust()


func _run_bust() -> bool:
	# Another tick crosses the threshold: busted, heat reported, exposure reset.
	_ctl._process(SECONDS_PER_BUST)
	if _wanted.crime_count != 1 or _busted_count != 1:
		return _fail("carrying contraband did not draw a bust (crimes %d)" % _wanted.crime_count)
	if _ctl.bust_exposure() != 0.0:
		return _fail("exposure did not reset after the bust (%.2f)" % _ctl.bust_exposure())

	# Still carrying: a loaded mule keeps drawing busts.
	_ctl._process(SECONDS_PER_BUST * 2.0)
	if _wanted.crime_count != 2:
		return _fail("a still-loaded mule stopped drawing heat (crimes %d)" % _wanted.crime_count)

	# Ditch the stash: the risk clears, no further busts.
	_ctl.market().drop("product", LOAD)
	_ctl._process(SECONDS_PER_BUST * 3.0)
	if _wanted.crime_count != 2:
		return _fail("kept drawing heat after ditching the stash (crimes %d)" % _wanted.crime_count)
	return _pass()


func _pass() -> bool:
	print(
		"contraband heat probe: OK (clean=no heat; loaded mule busts + reports a crime; ditched=clears)"
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("contraband heat probe FAIL :: %s" % message)
	print("contraband heat probe: FAIL — %s" % message)
	quit(1)
	return true
