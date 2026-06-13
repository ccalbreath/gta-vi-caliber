extends SceneTree
## Runtime wiring probe for the StockTerminal -> MarketEventCoordinator loop (and the
## seam HitContractBoard fires into), proven through the live node graph in a mock
## tree. The full "invest then move the market" loop: buy shares at the terminal, an
## in-world event spikes the price, sell the position for a profit. Also asserts the
## coordinator's apply_rivalry_shock (the hit board's sink) moves the live market.
## Physics overlap is the scene author's job; this probe emits body_entered
## directly. Run:
##   godot --headless --path game --script res://tests/stock_terminal_probe.gd

const WARMUP_FRAMES: int = 3
const COMPANY: String = "fruit_systems"
const SHARES: int = 10
const RICH: int = 1_000_000
const RIVAL: String = "bittn_tech"

var _ctl: MarketEventCoordinator = null
var _terminal: StockTerminal = null
var _stats: MockStats = null
var _player: StaticBody3D = null
var _frames: int = 0

var _bought_cost: int = -1
var _sold_proceeds: int = -1


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

	_ctl = MarketEventCoordinator.new()
	root.add_child(_ctl)

	_terminal = StockTerminal.new()
	_terminal.company_id = COMPANY
	_terminal.shares = SHARES
	_terminal.bought.connect(_on_bought)
	_terminal.sold.connect(_on_sold)
	root.add_child(_terminal)

	_player = StaticBody3D.new()
	_player.add_to_group("player")
	root.add_child(_player)


func _on_bought(_company: String, _qty: int, cost: int) -> void:
	_bought_cost = cost


func _on_sold(_company: String, _qty: int, proceeds: int) -> void:
	_sold_proceeds = proceeds


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	return _run_scenario()


func _run_scenario() -> bool:
	if _ctl == null or _terminal == null or _stats == null or _player == null:
		return _fail("mock tree did not assemble")
	var market: StockMarket = _ctl.market

	# Group gate: a non-player at the terminal trades nothing.
	var bystander := Node.new()
	root.add_child(bystander)
	_stats.money = RICH
	_terminal.body_entered.emit(bystander)
	if market.shares_held(COMPANY) != 0 or _stats.money != RICH:
		return _fail("a non-player traded at the terminal")

	# Buy a position (player arrives flat).
	var buy_price := market.price(COMPANY)
	_terminal.body_entered.emit(_player)
	if _bought_cost != buy_price * SHARES or market.shares_held(COMPANY) != SHARES:
		return _fail("buy did not charge price*shares / load the position")
	if _stats.money != RICH - _bought_cost:
		return _fail("buy wallet wrong: %d != %d" % [_stats.money, RICH - _bought_cost])

	return _run_sell(market, buy_price)


func _run_sell(market: StockMarket, buy_price: int) -> bool:
	# An in-world event spikes the held company (as a hit's spillover would).
	market.apply_company_event(COMPANY, 2.0)
	if market.price(COMPANY) <= buy_price:
		return _fail(
			"event did not raise the price (%d -> %d)" % [buy_price, market.price(COMPANY)]
		)

	# Sell the whole position at the new price (player arrives holding it).
	var banked := _stats.money
	_terminal.body_entered.emit(_player)
	if market.shares_held(COMPANY) != 0 or _stats.money != banked + _sold_proceeds:
		return _fail("sell did not clear the position / bank proceeds")
	if _sold_proceeds <= _bought_cost:
		return _fail(
			"no profit on the swing: proceeds %d <= cost %d" % [_sold_proceeds, _bought_cost]
		)

	return _assert_shock_seam(market)


# The controller exposes apply_rivalry_shock — the HitContractBoard's sink — and it
# must move the live market (a hit tanks the rival's stock).
func _assert_shock_seam(market: StockMarket) -> bool:
	var before := market.price(RIVAL)
	if not _ctl.apply_rivalry_shock(RIVAL, -0.6, 0.3):
		return _fail("apply_rivalry_shock rejected a valid company")
	if market.price(RIVAL) >= before:
		return _fail(
			"a hit's shock did not tank the rival (%d -> %d)" % [before, market.price(RIVAL)]
		)
	return _assert_unaffordable(market)


# A flat player who can't afford a share buys nothing and is charged nothing
# (the position was cleared by the sale, so entry takes the buy branch).
func _assert_unaffordable(market: StockMarket) -> bool:
	_stats.money = 0
	_terminal.body_entered.emit(_player)
	if market.shares_held(COMPANY) != 0 or _stats.money != 0:
		return _fail(
			(
				"an unaffordable buy was not a no-op (shares %d, money %d)"
				% [market.shares_held(COMPANY), _stats.money]
			)
		)
	return _pass()


func _pass() -> bool:
	print(
		(
			"stock terminal probe: OK (bought %s for $%d, sold for $%d, +$%d swing; hit-shock moves market)"
			% [COMPANY, _bought_cost, _sold_proceeds, _sold_proceeds - _bought_cost]
		)
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("stock terminal probe FAIL :: %s" % message)
	print("stock terminal probe: FAIL — %s" % message)
	quit(1)
	return true
