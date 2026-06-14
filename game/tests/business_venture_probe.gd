extends SceneTree
## Runtime wiring probe for BusinessVentureController + BusinessFront — the integration the
## pure-model unit tests (test_business_venture.gd) can't make: stepping into a front TAKES
## the racket over (acquire + stock + staff, charged to PlayerStats), the controller's day
## clock CONVERTS supply into product while you're away, a later visit CASHES OUT the
## stockpile into the wallet, and — the cross-system bit — a cash-out made while WANTED
## prices lower than a clean one (the controller reads the live wanted stars as a heat
## discount). Run:
##   godot --headless --path game --script res://tests/business_venture_probe.gd

const WARMUP_FRAMES: int = 3
const VENTURE: String = "coke_lab"
const PERIOD: float = 10.0
const START_MONEY: int = 100000
const ACQUIRE_COST: int = 50000
const RESTOCK: int = 50
const SUPPLY_COST: int = 200

var _ctrl: BusinessVentureController = null
var _front: BusinessFront = null
var _stats: MockStats = null
var _wanted: MockWanted = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_proceeds: int = 0
var _last_sold: int = 0
var _price1: float = 0.0


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount

	func spend_money(amount: int) -> bool:
		if amount > money:
			return false
		money -= amount
		return true


class MockWanted:
	extends Node
	var star_value: int = 0

	func _ready() -> void:
		add_to_group("wanted")

	func stars() -> int:
		return star_value


func _initialize() -> void:
	_stats = MockStats.new()
	_stats.money = START_MONEY
	root.add_child(_stats)
	_wanted = MockWanted.new()
	root.add_child(_wanted)

	_ctrl = BusinessVentureController.new()
	_ctrl.seconds_per_day = PERIOD
	_ctrl.set_process(false)
	_ctrl.cashed_out.connect(_on_cashed_out)
	root.add_child(_ctrl)

	_front = BusinessFront.new()
	_front.venture_id = VENTURE
	_front.acquire_cost = ACQUIRE_COST
	_front.restock_units = RESTOCK
	_front.supply_unit_cost = SUPPLY_COST
	root.add_child(_front)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_cashed_out(_id: String, proceeds: int, sold: int) -> void:
	_last_proceeds = proceeds
	_last_sold = sold


func _accrue_days(days: int) -> void:
	for _i in days:
		_ctrl._process(PERIOD)


## One physical visit: enter (acts once) then leave (re-arms the front for the next visit).
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
	var takeover_err := _check_takeover()
	if takeover_err != "":
		return takeover_err
	var production_err := _check_production()
	if production_err != "":
		return production_err
	var clean_err := _check_cashout_clean()
	if clean_err != "":
		return clean_err
	return _check_cashout_hot()


func _check_takeover() -> String:
	_visit()  # unowned -> take over + stock + staff
	if not _ctrl.owns(VENTURE):
		return "the front did not take the venture over"
	if _ctrl.staff_in(VENTURE) < 1 or _ctrl.supply_in(VENTURE) <= 0.0:
		return "takeover did not stock + staff the line"
	if _stats.money != START_MONEY - ACQUIRE_COST - RESTOCK * SUPPLY_COST:
		return "takeover did not charge acquire + restock (money %d)" % _stats.money
	return ""


func _check_production() -> String:
	if _ctrl.product_in(VENTURE) > 0.0:
		return "product existed before any production ran"
	_accrue_days(4)
	if _ctrl.product_in(VENTURE) <= 0.0:
		return "the day clock did not convert supply into product"
	return ""


func _check_cashout_clean() -> String:
	_wanted.star_value = 0
	var money_before := _stats.money
	var product_before := _ctrl.product_in(VENTURE)
	_visit()  # owned -> cash out + restock
	if _last_sold <= 0:
		return "a clean cash-out sold nothing"
	if _stats.money <= money_before:
		return "cash-out did not net positive proceeds"
	if _ctrl.product_in(VENTURE) >= product_before:
		return "cash-out did not draw down the stockpile"
	if _ctrl.gross_earned() < _last_proceeds:
		return "gross_earned did not record the cash-out (%d)" % _ctrl.gross_earned()
	_price1 = float(_last_proceeds) / float(_last_sold)
	return ""


func _check_cashout_hot() -> String:
	# The clean cash-out restocked the line, so production resumes; let it accrue, then a
	# HOT cash-out must price per-unit BELOW the clean one (live wanted-star heat discount).
	_accrue_days(4)
	if _ctrl.product_in(VENTURE) <= 0.0:
		return "production did not resume after the restock"
	_wanted.star_value = 5  # fully hot
	_visit()
	if _last_sold <= 0:
		return "a hot cash-out sold nothing"
	var price2 := float(_last_proceeds) / float(_last_sold)
	if price2 >= _price1:
		return "police heat did not discount the cash-out (%.0f vs %.0f)" % [price2, _price1]
	return ""


func _pass() -> bool:
	print(
		(
			(
				"business venture probe: OK (took over + stocked, day clock produced, clean "
				+ "cash-out paid $%.0f/unit, a hot cash-out was discounted below it)"
			)
			% _price1
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("business venture probe FAIL :: %s" % message)
	print("business venture probe: FAIL — %s" % message)
	quit(1)
	return true
