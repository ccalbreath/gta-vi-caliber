extends SceneTree
## Runtime wiring + economy probe for the live BrokerageTerminal in miami.tscn.
##
## Boots the real map, asserts the terminal is a registered interactable that trades
## the world's ONE LIVE market (the StockMarket owned by MarketEventCoordinator, the
## same market HitContractBoard shocks), then drives the trade loop against the LIVE
## player_stats wallet: interact once to BUY a lot (wallet drops by the buy cost,
## position opens), then move the LIVE price by feeding a market event to that SAME
## live market (proving the brokerage and the world share one market), interact again
## to SELL the whole position (wallet credited by the proceeds, position back to flat).
## Asserts the full buy->pump->sell round-trip moves the wallet coherently with no
## leakage. Self-contained. Run:
##   godot --headless --path game --script res://tests/brokerage_terminal_probe.gd

const SCENE_PATH: String = "res://scenes/world/miami.tscn"
const WARMUP_FRAMES: int = 90
## Cash fronted so the probe exercises the buy path, not the can't-afford branch.
const FRONT_MONEY: int = 200000
## Positive shock fed to the live market so the held position gains before the sell.
const PUMP_MAGNITUDE: float = 0.5
## Spillover used when pumping via the coordinator's apply_hit_effect path.
const PUMP_SPILLOVER: float = 0.0

var _scene: Node = null
var _frames: int = 0


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("brokerage terminal probe: scene failed to load")
		quit(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var err := _verify()
	if err.is_empty():
		quit(0)
	else:
		push_error("brokerage terminal probe FAIL: " + err)
		quit(1)
	return true


func _verify() -> String:
	var term := _scene.find_child("BrokerageTerminal", true, false) as BrokerageTerminal
	if term == null:
		print("BrokerageTerminal not present in miami.tscn")
		return "BrokerageTerminal not present in miami.tscn"
	var wiring_err := _verify_wiring(term)
	if not wiring_err.is_empty():
		return wiring_err
	return _verify_loop(term)


## The terminal is live, trades the shared LIVE market, is a registered interactable,
## starts flat.
func _verify_wiring(term: BrokerageTerminal) -> String:
	if term._market() == null:
		return "BrokerageTerminal found no live market (MarketEventCoordinator) in miami.tscn"
	if not term.is_in_group("interactables"):
		return "terminal not in group 'interactables'"
	if not term.has_method("interact") or not term.has_method("interact_prompt"):
		return "terminal does not answer the interactable contract"
	if term.position() != 0:
		return "terminal starts already holding a position (should buy on first interact)"
	return ""


## buy -> pump the LIVE price -> sell round trip against the live wallet, no leakage.
func _verify_loop(term: BrokerageTerminal) -> String:
	var player := get_first_node_in_group("player")
	var stats := get_first_node_in_group("player_stats")
	if player == null or stats == null or not ("money" in stats):
		return "no live player / player_stats node"
	if stats.has_method("add_money"):
		stats.add_money(FRONT_MONEY)

	var market: StockMarket = term._market()
	var money0: int = int(stats.money)
	var buy_unit: int = market.price(term.stock_id)
	term.interact(player)
	if term.position() <= 0:
		return "buy did not open a position (position %d)" % term.position()
	var after_buy: int = int(stats.money)
	var leak := _verify_buy_charge(term, money0, after_buy, buy_unit)
	if not leak.is_empty():
		return leak

	# Move the LIVE price the brokerage trades on by feeding the world its own market
	# event — the brokerage and the world share ONE market, so this changes the sell.
	if not _pump_live_market(market, term.stock_id):
		return "could not move the live market price"
	return _verify_sell(term, player, stats, after_buy)


## Pump the SAME live market the brokerage trades: prefer the coordinator's
## apply_hit_effect (the real world->market path), else apply a company event directly.
func _pump_live_market(market: StockMarket, id: String) -> bool:
	var coord := _coordinator_for(market)
	if coord != null:
		var effect := {"company_id": id, "magnitude": PUMP_MAGNITUDE, "spillover": PUMP_SPILLOVER}
		if bool(coord.apply_hit_effect(effect)):
			return true
	return market.apply_company_event(id, PUMP_MAGNITUDE)


## The scene node whose `market` IS this exact live StockMarket (MarketEventCoordinator),
## so the probe shocks the very market the brokerage trades. Null if none matches.
func _coordinator_for(market: StockMarket) -> Node:
	for node: Node in root.find_children("*", "Node", true, false):
		if node.get("market") == market and node.has_method("apply_hit_effect"):
			return node
	return null


## The buy debit equals price * lot_size exactly (wallet drops, no extra leak).
func _verify_buy_charge(
	term: BrokerageTerminal, money0: int, after_buy: int, buy_unit: int
) -> String:
	var expected_cost: int = buy_unit * term.position()
	var charged: int = money0 - after_buy
	if charged != expected_cost or charged <= 0:
		return "buy charge mismatch (charged %d, expected %d)" % [charged, expected_cost]
	return ""


## Selling the full position empties it and credits the wallet by the proceeds.
func _verify_sell(term: BrokerageTerminal, player: Node, stats: Node, after_buy: int) -> String:
	var held: int = term.position()
	var sell_unit: int = term._market().price(term.stock_id)
	var expected_proceeds: int = sell_unit * held
	term.interact(player)
	if term.position() != 0:
		return "sell did not close the position (position %d)" % term.position()
	var credited: int = int(stats.money) - after_buy
	if credited != expected_proceeds or credited <= 0:
		return "sell credit mismatch (credited %d, expected %d)" % [credited, expected_proceeds]
	print(
		(
			"brokerage terminal probe: OK (bought %d %s, wallet -> %d, sold for %d, wallet -> %d)"
			% [held, term.stock_id, after_buy, credited, int(stats.money)]
		)
	)
	return ""
