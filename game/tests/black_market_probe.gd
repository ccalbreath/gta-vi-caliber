extends SceneTree
## Runtime wiring probe for the BlackMarketStall -> ContrabandController arbitrage
## loop, proven through the live node graph in a mock tree (no scene file). Two
## stalls trade the same good in different districts; the probe picks a genuinely
## profitable route from the model's deterministic per-district prices, then drives
## the body_entered path: buy a parcel cheap at stall A, carry it (shared
## inventory), sell it dear at stall B.
##
## Asserts: the group gate ignores a non-player; buying charges exactly the local
## price and loads the stash; selling banks exactly the local price and clears the
## stash; the round trip nets a profit. Physics overlap is the scene author's job;
## this probe emits body_entered directly. Run:
##   godot --headless --path game --script res://tests/black_market_probe.gd

const WARMUP_FRAMES: int = 3
const GOOD: String = "product"
const RICH: int = 1_000_000
const BUY_QTY: int = 5
const CANDIDATES: Array = ["alpha", "bayfront", "downtown", "docks", "heights", "vice", "sands"]

var _ctl: ContrabandController = null
var _stall_a: BlackMarketStall = null
var _stall_b: BlackMarketStall = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0


class MockStats:
	extends Node
	var money: int = 0

	func _ready() -> void:
		add_to_group("player_stats")

	func add_money(amount: int) -> void:
		money += amount

	func spend_money(amount: int) -> void:
		money -= amount


func _initialize() -> void:
	_stats = MockStats.new()
	root.add_child(_stats)

	_ctl = ContrabandController.new()
	root.add_child(_ctl)

	_stall_a = BlackMarketStall.new()
	_stall_a.good = GOOD
	_stall_a.buy_qty = BUY_QTY
	root.add_child(_stall_a)

	_stall_b = BlackMarketStall.new()
	_stall_b.good = GOOD
	_stall_b.buy_qty = BUY_QTY
	root.add_child(_stall_b)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _stall_a == null or _stall_b == null or _stats == null or _player == null:
		return _fail("mock tree did not assemble")

	# Find a profitable route from the model's deterministic per-district prices.
	var market: ContrabandMarket = _ctl.market()
	var cheap := ""
	var dear := ""
	var lo: int = 1 << 30
	var hi: int = -1
	for raw: Variant in CANDIDATES:
		var district := str(raw)
		var price := market.price_in(GOOD, district)
		if price < lo:
			lo = price
			cheap = district
		if price > hi:
			hi = price
			dear = district
	if hi <= lo:
		return _fail("no profitable district spread found for %s" % GOOD)
	_stall_a.district_id = cheap
	_stall_b.district_id = dear

	# Group gate: a non-player body must not trade.
	var bystander := Node.new()
	root.add_child(bystander)
	_stats.money = RICH
	_stall_a.body_entered.emit(bystander)
	if _ctl.total_carried() != 0 or _stats.money != RICH:
		return _fail("a non-player body traded at the stall")

	return _run_trade(market, lo, hi)


func _run_trade(market: ContrabandMarket, lo: int, hi: int) -> bool:
	var expected_cost := lo * BUY_QTY
	var expected_proceeds := hi * BUY_QTY

	# Buy cheap at stall A (player arrives empty-handed).
	_stall_a.body_entered.emit(_player)
	if _stats.money != RICH - expected_cost:
		return _fail("buy charged %d, expected %d" % [RICH - _stats.money, expected_cost])
	if _ctl.carrying(GOOD) != BUY_QTY:
		return _fail("bought parcel not loaded: carrying %d" % _ctl.carrying(GOOD))

	# Carry to stall B and sell dear (player arrives holding the good).
	_stall_b.body_entered.emit(_player)
	if _stats.money != RICH - expected_cost + expected_proceeds:
		return _fail(
			(
				"sell banked %d, expected %d"
				% [_stats.money - (RICH - expected_cost), expected_proceeds]
			)
		)
	if _ctl.carrying(GOOD) != 0:
		return _fail("stash not cleared after sale: carrying %d" % _ctl.carrying(GOOD))

	var profit := expected_proceeds - expected_cost
	if profit <= 0:
		return _fail("route was not profitable: %d" % profit)
	return _assert_unaffordable(market, profit, expected_cost)


# An empty-handed visit you can't afford must buy nothing and take no money
# (guards the charge-before-carry order in _buy).
func _assert_unaffordable(market: ContrabandMarket, profit: int, expected_cost: int) -> bool:
	var broke := expected_cost - 1
	_stats.money = broke
	_stall_a.body_entered.emit(_player)
	if _stats.money != broke or _ctl.carrying(GOOD) != 0:
		return _fail(
			(
				"an unaffordable buy was not a no-op (money %d, carrying %d)"
				% [_stats.money, _ctl.carrying(GOOD)]
			)
		)
	return _pass(market, profit)


func _pass(market: ContrabandMarket, profit: int) -> bool:
	print(
		(
			"black market probe: OK (%s: buy %s @ %d, sell %s @ %d, profit +%d, stash cleared)"
			% [
				GOOD,
				_stall_a.district_id,
				market.price_in(GOOD, _stall_a.district_id),
				_stall_b.district_id,
				market.price_in(GOOD, _stall_b.district_id),
				profit,
			]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("black market probe FAIL :: %s" % message)
	print("black market probe: FAIL — %s" % message)
	quit(1)
	return true
