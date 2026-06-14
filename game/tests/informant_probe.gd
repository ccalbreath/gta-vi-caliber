extends SceneTree
## Runtime wiring probe for InformantController + Informant — the integration the pure-model unit
## tests (test_informant_network.gd) can't make: meeting an informant charges the retainer to
## PlayerStats to build trust, and once they trust you the SAME meet hands over a reliable cash
## tip (banked to PlayerStats) that spends their intel back down. Proves the pay-to-cultivate
## rhythm: a first retainer builds trust with no payoff, a second crosses into a paying tip. Run:
##   godot --headless --path game --script res://tests/informant_probe.gd

const WARMUP_FRAMES: int = 3
const FIXER: String = "fixer"  # tip_base 20000
const RETAINER: int = 3000  # 0.0001/$ -> 0.3 trust per retainer
const FIRST_TIP: int = 12000  # tip_base 20000 * trust 0.6
const START_MONEY: int = 10000

var _ctrl: InformantController = null
var _informant: Informant = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_cash: int = -1


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


func _initialize() -> void:
	_stats = MockStats.new()
	_stats.money = START_MONEY
	root.add_child(_stats)

	_ctrl = InformantController.new()
	root.add_child(_ctrl)

	_informant = Informant.new()
	_informant.informant_id = FIXER
	_informant.retainer = RETAINER
	_informant.met.connect(_on_met)
	root.add_child(_informant)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_met(_id: String, cash: int) -> void:
	_last_cash = cash


func _visit() -> void:
	_last_cash = -1  # reset the meet capture per visit
	_informant.body_entered.emit(_player)
	_informant.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _informant == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_cultivate, _check_first_tip, _check_cant_afford, _check_zero_retainer
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_cultivate() -> String:
	# First retainer: build trust, but the intel isn't good enough to pay yet.
	var m0 := _stats.money
	_visit()
	if _stats.money != m0 - RETAINER or _last_cash != 0:
		return (
			"the first retainer did not build trust without a payoff (money %d, cash %d)"
			% [_stats.money, _last_cash]
		)
	if _ctrl.is_reliable(FIXER):
		return "one retainer should not make the informant reliable yet"
	return ""


func _check_first_tip() -> String:
	# Second retainer crosses into a reliable tip: the meet pays the lead, net positive.
	var m0 := _stats.money
	_visit()
	if _last_cash != FIRST_TIP or _stats.money != m0 - RETAINER + FIRST_TIP:
		return (
			"a cultivated informant did not pay the reliable tip (cash %d, money %d)"
			% [_last_cash, _stats.money]
		)
	if _ctrl.is_reliable(FIXER):
		return "cashing the tip did not spend the informant's intel"
	return ""


func _check_cant_afford() -> String:
	# Too broke for the retainer: no spend, no trust built, no tip.
	_stats.money = RETAINER - 1
	var trust_before := _ctrl.trust_of(FIXER)
	var m0 := _stats.money
	_visit()
	if _stats.money != m0 or _last_cash != 0:
		return "a meet the player couldn't afford still charged / paid (money %d)" % _stats.money
	if not is_equal_approx(_ctrl.trust_of(FIXER), trust_before):
		return "a meet the player couldn't afford still built trust"
	return ""


func _check_zero_retainer() -> String:
	# A zero-retainer meet must NOT harvest a free tip — even from an informant still trusted enough
	# to pay (a big retainer leaves trust above the reliable line after the decay).
	_stats.money = 100000
	_ctrl.meet(FIXER, 20000)  # trust -> 1.0, cashes one tip, trust -> 0.7 (still reliable)
	if not _ctrl.is_reliable(FIXER):
		return "probe setup: a big retainer should leave the informant reliable"
	var money_before := _stats.money
	if _ctrl.meet(FIXER, 0) != 0 or _stats.money != money_before:
		return "a zero-retainer meet harvested a free tip (money %d)" % _stats.money
	return ""


func _pass() -> bool:
	print(
		(
			(
				"informant probe: OK (a first retainer built trust with no payoff, a second crossed "
				+ "into a reliable $%d tip that spent their intel, a broke meet did nothing)"
			)
			% FIRST_TIP
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("informant probe FAIL :: %s" % message)
	print("informant probe: FAIL — %s" % message)
	quit(1)
	return true
