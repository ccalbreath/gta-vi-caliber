extends SceneTree
## Runtime wiring probe for RomanceController + DateSpot — the integration the pure-model unit
## tests (test_romance.gd) can't make: stepping into a date venue charges the tab to PlayerStats
## and builds the partner's affection (a LOT at their favourite kind of venue, a little at a
## mismatch), and reaching commitment pays a one-time milestone gift. Partner "alex" likes dinner.
## Run:
##   godot --headless --path game --script res://tests/romance_probe.gd

const WARMUP_FRAMES: int = 3
const PARTNER: String = "alex"  # likes "dinner"
const COST: int = 1500
const START_MONEY: int = 20000

var _ctrl: RomanceController = null
var _dinner: DateSpot = null
var _club: DateSpot = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_hit: bool = false
var _gift: int = 0


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

	_ctrl = RomanceController.new()
	_ctrl.dated.connect(_on_dated)
	_ctrl.committed.connect(_on_committed)
	root.add_child(_ctrl)

	_dinner = _make_spot("dinner")
	_club = _make_spot("club")

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _make_spot(date_type: String) -> DateSpot:
	var spot := DateSpot.new()
	spot.partner_id = PARTNER
	spot.date_type = date_type
	spot.cost = COST
	root.add_child(spot)
	return spot


func _on_dated(_id: String, _affection: float, hit: bool) -> void:
	_last_hit = hit


func _on_committed(_id: String, gift: int) -> void:
	_gift = gift


func _visit(spot: DateSpot) -> void:
	_last_hit = false
	_gift = 0
	spot.body_entered.emit(_player)
	spot.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _dinner == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_mismatch, _check_match, _check_commit, _check_cant_afford, _check_zero_cost
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_mismatch() -> String:
	# alex doesn't like the club: charged, but barely any affection.
	var m0 := _stats.money
	_visit(_club)
	if _last_hit or _stats.money != m0 - COST:
		return "a mismatched date was wrongly a hit / not charged (money %d)" % _stats.money
	if not is_equal_approx(_ctrl.affection_of(PARTNER), Romance.MISS_GAIN):
		return "a mismatched date built the wrong affection (%f)" % _ctrl.affection_of(PARTNER)
	return ""


func _check_match() -> String:
	# Their favourite venue builds a lot more affection.
	var m0 := _stats.money
	var before := _ctrl.affection_of(PARTNER)
	_visit(_dinner)
	if not _last_hit or _stats.money != m0 - COST:
		return "a favourite-venue date was not a hit / not charged"
	if not is_equal_approx(_ctrl.affection_of(PARTNER) - before, Romance.HIT_GAIN):
		return (
			"the favourite date did not build the full affection (%f)" % _ctrl.affection_of(PARTNER)
		)
	return ""


func _check_commit() -> String:
	# One more good date crosses into commitment, paying the one-time gift.
	var m0 := _stats.money
	_visit(_dinner)
	if not _ctrl.is_committed(PARTNER):
		return "enough good dates did not reach commitment (%f)" % _ctrl.affection_of(PARTNER)
	if (
		_gift != RomanceController.COMMIT_GIFT
		or _stats.money != m0 - COST + RomanceController.COMMIT_GIFT
	):
		return (
			"commitment did not pay the milestone gift (gift %d, money %d)" % [_gift, _stats.money]
		)
	return ""


func _check_cant_afford() -> String:
	# Too broke for the tab: no charge, no affection built.
	_stats.money = COST - 1
	var before := _ctrl.affection_of(PARTNER)
	var m0 := _stats.money
	_visit(_dinner)
	if _stats.money != m0 or not is_equal_approx(_ctrl.affection_of(PARTNER), before):
		return "a date the player couldn't afford still charged / built affection"
	return ""


func _check_zero_cost() -> String:
	# A free date must not court your way to the (cash) gift: no charge, no affection built.
	_stats.money = START_MONEY
	var before := _ctrl.affection_of(PARTNER)
	var m0 := _stats.money
	_ctrl.go_on_date(PARTNER, "dinner", 0)
	if _stats.money != m0 or not is_equal_approx(_ctrl.affection_of(PARTNER), before):
		return "a zero-cost date built affection or charged the wallet"
	return ""


func _pass() -> bool:
	print(
		(
			"romance probe: OK (a mismatched date barely moved them, their favourite venue built "
			+ "real affection, enough good dates committed for the gift, a broke date did nothing)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("romance probe FAIL :: %s" % message)
	print("romance probe: FAIL — %s" % message)
	quit(1)
	return true
