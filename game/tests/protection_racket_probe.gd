extends SceneTree
## Runtime wiring probe for ProtectionRacketController + ShakedownFront — the integration the
## pure-model unit tests (test_protection_racket.gd) can't make: stepping into a front leans on
## it (it starts paying, drawing police heat) and pockets the accrued tribute; the controller's
## day clock pays tribute from compliant fronts and FADES their fear; NEGLECT a front and it
## turns DEFIANT and stops paying until you lean on it again. Run:
##   godot --headless --path game --script res://tests/protection_racket_probe.gd

const WARMUP_FRAMES: int = 3
const FRONT: String = "liquor_store"
const PERIOD: float = 10.0

var _ctrl: ProtectionRacketController = null
var _front: ShakedownFront = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0


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

	_ctrl = ProtectionRacketController.new()
	_ctrl.shake_force = 0.9
	_ctrl.seconds_per_day = PERIOD
	_ctrl.set_process(false)
	root.add_child(_ctrl)

	_front = ShakedownFront.new()
	_front.front_id = FRONT
	root.add_child(_front)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _visit() -> void:
	_front.body_entered.emit(_player)
	_front.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _front == null or _stats == null:
		return _fail("mock tree did not assemble")
	var err := _run_checks()
	if err != "":
		return _fail(err)
	return _pass()


func _run_checks() -> String:
	var checks: Array[Callable] = [
		_check_first_rounds,
		_check_tribute_accrues,
		_check_collect,
		_check_defiance,
		_check_reshake,
		_check_wallet_guard,
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return err
	return ""


func _check_first_rounds() -> String:
	var crimes_before := _wanted.crimes
	var money_before := _stats.money
	_visit()  # first round: lean on the front (+heat), nothing to collect yet
	if not _ctrl.is_compliant(FRONT):
		return "the shakedown did not bring the front into line"
	if _wanted.crimes <= crimes_before:
		return "leaning on the front did not draw police heat"
	if _stats.money != money_before:
		return "collected tribute before any had accrued (money %d)" % _stats.money
	return ""


func _check_tribute_accrues() -> String:
	var before := _ctrl.pending_tribute()
	_ctrl._process(PERIOD)  # day 1
	_ctrl._process(PERIOD)  # day 2
	if _ctrl.pending_tribute() <= before:
		return (
			"tribute did not accrue from the compliant front (pending %d)" % _ctrl.pending_tribute()
		)
	return ""


func _check_collect() -> String:
	var money_before := _stats.money
	var pending := _ctrl.pending_tribute()
	_visit()  # rounds: bank the tribute AND re-intimidate
	if _stats.money != money_before + pending:
		return "the rounds did not bank the accrued tribute (money %d)" % _stats.money
	if _ctrl.pending_tribute() != 0:
		return "the tribute pot was not emptied on collection"
	if _ctrl.intimidation_of(FRONT) < 0.9 - 0.001:
		return "the rounds did not re-intimidate the front (%f)" % _ctrl.intimidation_of(FRONT)
	return ""


func _check_defiance() -> String:
	# Neglect the front: fear fades day by day until it turns defiant and stops paying.
	var days := 0
	while not _ctrl.is_defiant(FRONT) and days < 20:
		_ctrl._process(PERIOD)
		days += 1
	if not _ctrl.is_defiant(FRONT):
		return "the neglected front never turned defiant in %d days" % days
	var pending_at_defiance := _ctrl.pending_tribute()
	_ctrl._process(PERIOD)
	if _ctrl.pending_tribute() != pending_at_defiance or _ctrl.daily_income() != 0:
		return "a defiant front kept paying tribute"
	return ""


func _check_reshake() -> String:
	_visit()  # lean on them again -> back into line
	if not _ctrl.is_compliant(FRONT):
		return "re-leaning on a defiant front did not bring it back into line"
	var before := _ctrl.pending_tribute()
	_ctrl._process(PERIOD)
	if _ctrl.pending_tribute() <= before:
		return "the re-shaken front did not resume paying tribute"
	return ""


func _check_wallet_guard() -> String:
	# Build up some tribute, then a collect with NO wallet present must return 0 and must NOT
	# drop the pot (the guard charges the model only when the wallet can receive the cash).
	_ctrl._process(PERIOD)  # accrue a day -> pending > 0
	var pending := _ctrl.pending_tribute()
	if pending <= 0:
		return "expected pending tribute before the wallet-guard check"
	_stats.remove_from_group("player_stats")
	var banked := _ctrl.collect()
	_stats.add_to_group("player_stats")  # restore the wallet
	if banked != 0 or _ctrl.pending_tribute() != pending:
		return (
			"a wallet-less collect dropped the tribute pot (banked %d, pending %d)"
			% [banked, _ctrl.pending_tribute()]
		)
	return ""


func _pass() -> bool:
	print(
		(
			"protection racket probe: OK (a shakedown brought the front into line + drew heat, "
			+ "tribute accrued and was collected, neglect turned it defiant, re-leaning resumed it)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("protection racket probe FAIL :: %s" % message)
	print("protection racket probe: FAIL — %s" % message)
	quit(1)
	return true
