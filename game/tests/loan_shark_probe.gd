extends SceneTree
## Runtime wiring probe for LoanSharkController + LoanSharkDen — the integration the pure-
## model unit tests (test_loan_shark.gd) can't make: stepping into the den DEBT-FREE takes a
## loan (cash to PlayerStats, debt recorded), the controller's day clock COMPOUNDS the
## interest, a later visit while OWING makes a PAYMENT (cash from the wallet), letting the
## debt balloon unpaid DEFAULTS it and sends the shark's muscle (a heat spike on the wanted
## system) exactly once, and paying the full balance CLEARS it. Run:
##   godot --headless --path game --script res://tests/loan_shark_probe.gd

const WARMUP_FRAMES: int = 3
const PERIOD: float = 10.0
const LOAN: int = 20000
const PAYMENT: int = 8000
const START_MONEY: int = 50000

var _ctrl: LoanSharkController = null
var _den: LoanSharkDen = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _defaulted_count: int = 0
var _loan_taken: int = 0


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount

	func spend_money(amount: int) -> bool:
		if amount <= 0 or money < amount:
			return false
		money -= amount
		return true


class MockWanted:
	extends Node
	var crimes: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func report_crime(_killed: bool) -> void:
		crimes += 1


func _initialize() -> void:
	_stats = MockStats.new()
	_stats.money = START_MONEY
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	_ctrl = LoanSharkController.new()
	_ctrl.daily_rate = 0.05
	_ctrl.credit_limit = 100000
	_ctrl.seconds_per_day = PERIOD
	_ctrl.set_process(false)
	_ctrl.loan_defaulted.connect(_on_defaulted)
	root.add_child(_ctrl)

	_den = LoanSharkDen.new()
	_den.loan_amount = LOAN
	_den.payment_amount = PAYMENT
	_den.loan_taken.connect(_on_loan_taken)
	root.add_child(_den)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_defaulted(_owed: int) -> void:
	_defaulted_count += 1


func _on_loan_taken(amount: int) -> void:
	_loan_taken = amount


func _visit() -> void:
	_den.body_entered.emit(_player)
	_den.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _den == null or _stats == null:
		return _fail("mock tree did not assemble")
	var err := _run_checks()
	if err != "":
		return _fail(err)
	return _pass()


func _run_checks() -> String:
	var checks: Array[Callable] = [
		_check_borrow, _check_interest, _check_repay, _check_default, _check_redefault, _check_clear
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return err
	return ""


func _check_borrow() -> String:
	var money_before := _stats.money
	_visit()  # debt-free -> take a loan
	if not _ctrl.has_debt() or _ctrl.owed() != LOAN or _loan_taken != LOAN:
		return "the den did not take out the loan (owed %d)" % _ctrl.owed()
	if _stats.money != money_before + LOAN:
		return "the loan cash was not disbursed to the wallet (money %d)" % _stats.money
	return ""


func _check_interest() -> String:
	var owed_before := _ctrl.owed()
	_ctrl._process(PERIOD)  # day 1
	_ctrl._process(PERIOD)  # day 2
	if _ctrl.owed() <= owed_before:
		return "the debt did not compound over days (owed %d)" % _ctrl.owed()
	return ""


func _check_repay() -> String:
	var money_before := _stats.money
	var owed_before := _ctrl.owed()
	_visit()  # owing -> make a payment
	if _ctrl.owed() >= owed_before:
		return "the payment did not reduce the debt (owed %d)" % _ctrl.owed()
	if _stats.money != money_before - PAYMENT:
		return "the payment did not come from the wallet (money %d)" % _stats.money
	return ""


func _check_default() -> String:
	# Let the debt balloon unpaid until it defaults -> enforcers (a heat spike).
	var crimes_before := _wanted.crimes
	var days := 0
	while not _ctrl.is_defaulted() and days < 60:
		_ctrl._process(PERIOD)
		days += 1
	if not _ctrl.is_defaulted():
		return "the debt never defaulted after %d days (owed %d)" % [days, _ctrl.owed()]
	var heat := _wanted.crimes - crimes_before
	if _defaulted_count != 1 or heat != LoanSharkController.ENFORCER_HEAT_REPORTS:
		return (
			"default did not send enforcers exactly once (count %d, heat %d)"
			% [_defaulted_count, heat]
		)
	# Enforcers come ONCE per default, not every day the debt stays blown.
	var crimes_after := _wanted.crimes
	_ctrl._process(PERIOD)
	if _wanted.crimes != crimes_after or _defaulted_count != 1:
		return "the default re-fired the enforcers on a later day"
	return ""


func _check_redefault() -> String:
	# Pay the defaulted debt DOWN below the threshold (not clear), then let it re-balloon: the
	# enforcers must come a SECOND time — the once-fire flag re-arms on a payment that drops
	# out of default. (Guards the narrow-band re-arm gap.)
	var owed := _ctrl.owed()
	_stats.money = owed  # fund the large partial payment
	_ctrl.repay(owed - 5000)  # leave ~5000 owed, far below the default threshold
	if _ctrl.is_defaulted() or not _ctrl.has_debt():
		return (
			"the large partial repay did not drop the debt below default (owed %d)" % _ctrl.owed()
		)
	var count_before := _defaulted_count
	var days := 0
	while not _ctrl.is_defaulted() and days < 90:
		_ctrl._process(PERIOD)
		days += 1
	if not _ctrl.is_defaulted():
		return "the re-armed debt never re-defaulted in %d days" % days
	if _defaulted_count != count_before + 1:
		return "a re-ballooned debt did not re-fire the enforcers (count %d)" % _defaulted_count
	return ""


func _check_clear() -> String:
	var owed := _ctrl.owed()
	_stats.money = owed + 1000  # make sure the wallet can cover the full payoff
	var paid := _ctrl.repay(owed)
	if paid != owed or _ctrl.has_debt() or _ctrl.is_defaulted():
		return (
			"paying the full balance did not clear the debt (paid %d, owed %d)"
			% [paid, _ctrl.owed()]
		)
	if _stats.money != 1000:
		return "the payoff did not take the full balance from the wallet (money %d)" % _stats.money
	return ""


func _pass() -> bool:
	print(
		(
			(
				"loan shark probe: OK (took a $%d loan, interest compounded, a payment cut it down, "
				+ "ballooning defaulted it once with a heat spike, a full payoff cleared it)"
			)
			% LOAN
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("loan shark probe FAIL :: %s" % message)
	print("loan shark probe: FAIL — %s" % message)
	quit(1)
	return true
