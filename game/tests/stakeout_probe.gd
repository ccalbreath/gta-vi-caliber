extends SceneTree
## Runtime wiring probe for StakeoutController + ScoreTarget — the integration the pure-model
## unit tests (test_stakeout.gd) can't make: the first visit MARKS the score (casing begins), the
## controller's day clock builds RECON over time, a later visit MOVES IN for a take scaled by how
## well it was cased — banked to PlayerStats with the robbery's heat reported (and, on a rushed
## job, the alarm) — and a finished score is a no-op. Run:
##   godot --headless --path game --script res://tests/stakeout_probe.gd

const WARMUP_FRAMES: int = 3
const BASE: int = 30000
const PERIOD: float = 10.0

var _ctrl: StakeoutController = null
var _rushed: StakeoutController = null
var _target: ScoreTarget = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_take: int = -1
var _last_alarm: bool = false


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount


class MockWanted:
	extends Node
	var crimes: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		crimes += 1


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	_ctrl = StakeoutController.new()
	_ctrl.base_take = BASE
	_ctrl.seconds_per_day = PERIOD
	_ctrl.set_process(false)
	_ctrl.moved_in.connect(_on_moved_in)
	root.add_child(_ctrl)  # added first -> the ScoreTarget binds THIS one

	# A second score driven directly (never via the zone) to exercise the rushed/alarm path
	# without the day clock or a group collision.
	_rushed = StakeoutController.new()
	_rushed.base_take = BASE
	_rushed.set_process(false)
	root.add_child(_rushed)

	_target = ScoreTarget.new()
	root.add_child(_target)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_moved_in(take: int, alarm: bool) -> void:
	_last_take = take
	_last_alarm = alarm


func _visit() -> void:
	_target.body_entered.emit(_player)
	_target.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _target == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_mark_and_case, _check_no_wallet, _check_move_in, _check_redo, _check_rushed_alarm
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_mark_and_case() -> String:
	# First visit marks the score; nothing is cased yet.
	_visit()
	if not _ctrl.is_marked() or _ctrl.recon() != 0.0:
		return "the first visit did not mark the score for casing"
	# The crew cases it over a few days -> recon climbs above the alarm line.
	for _i in 3:
		_ctrl._process(PERIOD)
	if _ctrl.recon() <= 0.0 or _ctrl.is_done():
		return "casing did not build recon over days (%f)" % _ctrl.recon()
	return ""


func _check_no_wallet() -> String:
	# With no wallet to bank into, moving in must NOT consume the score — it stays retryable.
	_stats.remove_from_group("player_stats")
	_visit()
	var untouched := not _ctrl.is_done()
	_stats.add_to_group("player_stats")  # restore for the real hit
	if not untouched:
		return "moving in with no wallet still consumed the score"
	return ""


func _check_move_in() -> String:
	# Move in: the take must match the model's projection at the cased recon, paid + reported.
	var expected := _ctrl.projected_take()
	var money_before := _stats.money
	var crimes_before := _wanted.crimes
	_visit()
	if _last_take != expected or _stats.money != money_before + expected:
		return "the cased take was wrong (take %d, expected %d)" % [_last_take, expected]
	if _last_alarm or _wanted.crimes != crimes_before + 1:
		return (
			"a well-cased job should be clean (alarm %s, heat +%d)"
			% [_last_alarm, _wanted.crimes - crimes_before]
		)
	if not _ctrl.is_done():
		return "the score was not marked done after moving in"
	return ""


func _check_redo() -> String:
	# A finished score is a no-op.
	var money_before := _stats.money
	_visit()
	if _stats.money != money_before:
		return "re-hitting a finished score paid again (money %d)" % _stats.money
	return ""


func _check_rushed_alarm() -> String:
	# A rushed hit at recon 0 (no casing): a smaller take AND the alarm — two heat events.
	_rushed.mark()
	var expected := _rushed.projected_take()  # base * min_fraction
	var crimes_before := _wanted.crimes
	var take := _rushed.move_in()
	if take != expected or take >= BASE:
		return "a rushed hit was not the smaller blind take (%d)" % take
	if _wanted.crimes != crimes_before + 2:
		return "the alarm did not bring extra heat (+%d)" % (_wanted.crimes - crimes_before)
	return ""


func _pass() -> bool:
	print(
		(
			"stakeout probe: OK (a visit marked the score, the crew cased it over days, moving in "
			+ "paid the recon-scaled take clean, and the finished score was a no-op)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("stakeout probe FAIL :: %s" % message)
	print("stakeout probe: FAIL — %s" % message)
	quit(1)
	return true
