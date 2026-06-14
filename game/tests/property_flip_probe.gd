extends SceneTree
## Runtime wiring probe for RealtyController + PropertyListing — the integration the pure-model unit
## tests (test_property_flip.gd) can't make: stepping into a property listing advances the flip one
## stage per visit (buy → renovate → sell), charging the purchase + renovation to PlayerStats and
## banking the sale, for a net appreciation profit. A sold property doesn't re-trade and a listing
## the player can't afford doesn't move.
## Run:
##   godot --headless --path game --script res://tests/property_flip_probe.gd

const WARMUP_FRAMES: int = 3
const DEAL: String = "harbor_loft"  # price 40000, reno 25000, resale 90000
const PRICE: int = 40000
const RENO: int = 25000
const RESALE: int = 90000
const PRICE2: int = 75000  # vice_bungalow — used for the can't-afford check
const START_MONEY: int = 200000

var _ctrl: RealtyController = null
var _listing: PropertyListing = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0
var _last_state: String = ""
var _sold_profit: int = -1


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

	_ctrl = RealtyController.new()
	_ctrl.sold.connect(_on_sold)
	root.add_child(_ctrl)

	_listing = PropertyListing.new()
	_listing.property_id = DEAL
	_listing.advanced.connect(_on_advanced)
	root.add_child(_listing)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_advanced(_id: String, state: String) -> void:
	_last_state = state


func _on_sold(_id: String, _proceeds: int, profit: int) -> void:
	_sold_profit = profit


func _visit() -> void:
	_listing.body_entered.emit(_player)
	_listing.body_exited.emit(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctrl == null or _listing == null or _stats == null:
		return _fail("mock tree did not assemble")
	var checks: Array[Callable] = [
		_check_buy,
		_check_renovate,
		_check_sell,
		_check_sold_noop,
		_check_cant_afford,
		_check_cant_afford_reno,
	]
	for check in checks:
		var err: String = check.call()
		if err != "":
			return _fail(err)
	return _pass()


func _check_buy() -> String:
	var m0 := _stats.money
	_visit()
	if _last_state != PropertyFlip.STATE_OWNED or _stats.money != m0 - PRICE:
		return "buying did not take ownership / charge the price (money %d)" % _stats.money
	return ""


func _check_renovate() -> String:
	var m0 := _stats.money
	_visit()
	if _last_state != PropertyFlip.STATE_RENOVATED or _stats.money != m0 - RENO:
		return "renovating did not advance / charge the work (money %d)" % _stats.money
	return ""


func _check_sell() -> String:
	var m0 := _stats.money
	_visit()
	if _last_state != PropertyFlip.STATE_SOLD or _stats.money != m0 + RESALE:
		return "selling did not bank the resale (money %d)" % _stats.money
	if _sold_profit != RESALE - PRICE - RENO:
		return "the flip reported the wrong profit (%d)" % _sold_profit
	return ""


func _check_sold_noop() -> String:
	var m0 := _stats.money
	_visit()
	if _stats.money != m0 or _last_state != PropertyFlip.STATE_SOLD:
		return "a sold property was wrongly re-traded (money %d)" % _stats.money
	return ""


func _check_cant_afford() -> String:
	# A fresh listing the player can't cover stays on the market, no charge.
	_stats.money = PRICE2 - 1
	var listing := PropertyListing.new()
	listing.property_id = "vice_bungalow"
	root.add_child(listing)
	var m0 := _stats.money
	listing.body_entered.emit(_player)
	listing.body_exited.emit(_player)
	if _stats.money != m0 or _ctrl.state_of("vice_bungalow") != PropertyFlip.STATE_AVAILABLE:
		return "a property the player couldn't afford was still bought (money %d)" % _stats.money
	return ""


func _check_cant_afford_reno() -> String:
	# Buy a lot, then go broke before renovating: the half-done flip must stall at owned, no charge.
	var lot := "downtown_condo"
	var listing := PropertyListing.new()
	listing.property_id = lot
	root.add_child(listing)
	_stats.money = _ctrl.price_of(lot)
	listing.body_entered.emit(_player)  # buy succeeds
	listing.body_exited.emit(_player)
	if _ctrl.state_of(lot) != PropertyFlip.STATE_OWNED:
		return "could not set up an owned lot for the broke-reno check"
	_stats.money = _ctrl.reno_cost_of(lot) - 1  # can't cover the renovation
	var m0 := _stats.money
	listing.body_entered.emit(_player)  # renovate should fail
	listing.body_exited.emit(_player)
	if _stats.money != m0 or _ctrl.state_of(lot) != PropertyFlip.STATE_OWNED:
		return (
			"a player who couldn't afford the reno was still charged / advanced (money %d)"
			% _stats.money
		)
	return ""


func _pass() -> bool:
	print(
		(
			"property flip probe: OK (bought a run-down property, paid to renovate it, sold it for a "
			+ "net profit, a sold lot didn't re-trade, and a listing beyond the wallet stayed put)"
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("property flip probe FAIL :: %s" % message)
	print("property flip probe: FAIL — %s" % message)
	quit(1)
	return true
