extends SceneTree
## Runtime wiring probe for ParoleController — the integration the pure-model unit tests
## (test_parole_terms.gd) can't make: that the controller CONSUMES the live wanted node's
## stars_changed (one spree = one violation, debounced until the stars cool), that hitting
## the violation cap REVOKES parole and FEEDS BACK a heat spike into the wanted system,
## and that a clean run of in-game days (driven on the controller's own clock) COMPLETES
## parole and pays the freedom bonus into player_stats. Run:
##   godot --headless --path game --script res://tests/parole_probe.gd
##
## Two controllers are isolated by juggling group membership at bind time so the shared
## "wanted" group can't cross-trigger them: ctrl_c binds to an out-of-group wanted (it
## only runs its day clock), ctrl_v binds to the in-group wanted (it takes the stars).

const WARMUP_FRAMES: int = 3
const PERIOD: float = 10.0
const REWARD: int = 7500

var _wanted_v: MockWanted = null
var _wanted_c: MockWanted = null
var _stats: MockStats = null
var _ctrl_v: ParoleController = null
var _ctrl_c: ParoleController = null
var _frames: int = 0
var _revoked: bool = false
var _last_violation: int = -1
var _completed_reward: int = -1


class MockWanted:
	extends Node
	signal stars_changed(stars: int)
	var heat_reports: int = 0

	func report_crime(_killed: bool) -> void:
		heat_reports += 1
		# Faithfully RE-ENTER the listener like the live WantedTracker does (its heat bump
		# re-emits stars_changed), so the probe actually EXERCISES the revocation feedback
		# loop's re-entrancy guards instead of silently absorbing the spike.
		stars_changed.emit(mini(heat_reports, 5))

	func emit_stars(stars: int) -> void:
		stars_changed.emit(stars)


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


func _initialize() -> void:
	_wanted_v = MockWanted.new()
	root.add_child(_wanted_v)
	_wanted_c = MockWanted.new()
	root.add_child(_wanted_c)
	_stats = MockStats.new()
	root.add_child(_stats)

	_ctrl_v = ParoleController.new()
	_ctrl_v.violations_to_revoke = 2
	_ctrl_v.set_process(false)
	_ctrl_v.parole_revoked.connect(_on_revoked)
	_ctrl_v.violation_recorded.connect(_on_violation)
	root.add_child(_ctrl_v)

	_ctrl_c = ParoleController.new()
	_ctrl_c.clean_days_to_complete = 2
	_ctrl_c.completion_reward = REWARD
	_ctrl_c.seconds_per_day = PERIOD
	_ctrl_c.set_process(false)
	_ctrl_c.parole_completed.connect(_on_completed)
	root.add_child(_ctrl_c)


func _on_revoked() -> void:
	_revoked = true


func _on_violation(count: int) -> void:
	_last_violation = count


func _on_completed(reward: int) -> void:
	_completed_reward = reward


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl_v == null or _ctrl_c == null or _stats == null:
		return _fail("mock tree did not assemble")
	_bind_isolated()
	var completion_err := _check_completion()
	if completion_err != "":
		return _fail(completion_err)
	var revoke_err := _check_violation_revoke()
	if revoke_err != "":
		return _fail(revoke_err)
	return _pass()


## Bind each controller to its own wanted: ctrl_c to the out-of-group one (it never takes
## stars), ctrl_v to the in-group one (it does). Order matters — bind ctrl_c while only
## wanted_c is in the group, then hand the group to wanted_v for ctrl_v.
func _bind_isolated() -> void:
	_wanted_c.add_to_group("wanted")
	_ctrl_c._process(0.0)  # force _bind_wanted -> wanted_c
	_wanted_c.remove_from_group("wanted")
	_wanted_v.add_to_group("wanted")
	_ctrl_v._process(0.0)  # force _bind_wanted -> wanted_v ; left in the group for _punish


func _check_completion() -> String:
	_ctrl_c._process(PERIOD * 0.4)  # a partial day must NOT tick the streak
	if _ctrl_c.clean_streak() != 0:
		return "a partial day advanced the clean streak"
	_ctrl_c._process(PERIOD)  # day 1
	_ctrl_c._process(PERIOD)  # day 2 -> complete
	if _ctrl_c.is_on_parole() or _ctrl_c.outcome() != "completed":
		return "parole did not complete after a clean streak (outcome %s)" % _ctrl_c.outcome()
	if _completed_reward != REWARD or _stats.money != REWARD:
		return "completion did not pay the freedom bonus (money %d)" % _stats.money
	return ""


func _check_violation_revoke() -> String:
	_wanted_v.emit_stars(2)  # violation 1
	_wanted_v.emit_stars(3)  # same spree -> debounced
	if _ctrl_v.violation_count() != 1 or _last_violation != 1:
		return "a single spree was double-counted (count %d)" % _ctrl_v.violation_count()
	if not _ctrl_v.is_on_parole():
		return "parole ended after a single violation"
	_wanted_v.emit_stars(0)  # cool down -> re-arm the debounce
	_wanted_v.emit_stars(1)  # violation 2 -> revoke
	if _ctrl_v.is_on_parole() or _ctrl_v.outcome() != "revoked" or not _revoked:
		return "parole was not revoked at the violation cap"
	# The heat spike must land EXACTLY REVOCATION_HEAT_REPORTS times AND its re-entrant
	# stars_changed must NOT inflate the violation count past the 2 that revoked parole.
	if (
		_wanted_v.heat_reports != ParoleController.REVOCATION_HEAT_REPORTS
		or _ctrl_v.violation_count() != 2
	):
		return (
			"revocation feedback wrong (reports %d, violations %d)"
			% [_wanted_v.heat_reports, _ctrl_v.violation_count()]
		)
	return ""


func _pass() -> bool:
	print(
		(
			(
				"parole probe: OK (spree debounced then revoked with a heat spike; "
				+ "a clean streak completed parole for $%d)"
			)
			% REWARD
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("parole probe FAIL :: %s" % message)
	print("parole probe: FAIL — %s" % message)
	quit(1)
	return true
