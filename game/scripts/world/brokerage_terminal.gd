class_name BrokerageTerminal
extends Node3D
## A walk-up stock-trading terminal: face it, press interact, and the first press
## BUYS a lot of one company's shares (charged to PlayerStats); every later press
## SELLS the whole position back at the live price (proceeds credited to
## PlayerStats). It trades the world's ONE LIVE market — the StockMarket owned by
## MarketEventCoordinator — so a held position gains or loses value as world events
## move prices (a completed HitContract shocks the rival's stock; a rising wanted
## level rallies defense), closing the "invest, take the hit, cash out" loop. The
## terminal only reads + trades the shared market; it never drives the price itself.
##
## The Interactable contract (see Interaction): joins group "interactables" and
## answers interact_prompt() + interact(player). All money is resolved against the
## live wallet; StockMarket itself never touches PlayerStats — we apply its returned
## cost/proceeds ourselves via the guarded spend_money()/add_money() paths. The live
## market is located by capability (a node exposing a StockMarket `market`), mirroring
## how HitContractBoard finds the market it shocks — so both act on the same prices.

## Fired when the player opens a position (company id, shares bought, cost charged).
signal shares_bought(id: String, qty: int, cost: int)
## Fired when the player closes a position (company id, total proceeds credited).
signal shares_sold(id: String, proceeds: int)

## StockMarket company id this terminal trades (must exist in the roster).
@export var stock_id: String = "bittn_tech"
## Shares bought per "open position" press.
@export var lot_size: int = 10

var _stats: Node = null
var _market_cache: StockMarket = null


func _ready() -> void:
	add_to_group("interactables")


## HUD hint: the company, its live price, and whether the next press buys or sells.
func interact_prompt() -> String:
	var market := _market()
	var unit := market.price(stock_id) if market != null else -1
	var held := position()
	if held > 0:
		return "Sell %d %s @ $%d" % [held, stock_id, unit]
	return "Buy %d %s @ $%d" % [lot_size, stock_id, unit]


## First press opens a position; every later press closes it. No-op if the world has
## no live market to trade against.
func interact(_player: Node) -> void:
	if _market() == null:
		return
	if position() > 0:
		_sell()
	else:
		_buy()


## Buy lot_size shares at the live price, charge the returned cost to the wallet.
## No-op if the wallet is absent or the buy is unaffordable.
func _buy() -> void:
	var stats := _player_stats()
	if stats == null or not ("money" in stats):
		return
	var result: Dictionary = _market().buy(stock_id, lot_size, int(stats.money))
	if not result.get("success", false) or not stats.has_method("spend_money"):
		return
	var cost: int = int(result["cost"])
	if not stats.spend_money(cost):
		return
	shares_bought.emit(stock_id, lot_size, cost)


## Sell the whole held position at the live price and bank the proceeds.
func _sell() -> void:
	var held := position()
	if held <= 0:
		return
	var result: Dictionary = _market().sell(stock_id, held)
	if not result.get("success", false):
		return
	var proceeds: int = int(result["proceeds"])
	var stats := _player_stats()
	if proceeds <= 0 or stats == null or not stats.has_method("add_money"):
		return
	stats.add_money(proceeds)
	shares_sold.emit(stock_id, proceeds)


## Shares currently held in this terminal's company (0 if flat / no live market),
## for a HUD readout.
func position() -> int:
	var market := _market()
	return market.shares_held(stock_id) if market != null else 0


func _player_stats() -> Node:
	if _stats == null or not is_instance_valid(_stats):
		_stats = get_tree().get_first_node_in_group("player_stats")
	return _stats


## The world's ONE live market: the StockMarket owned by MarketEventCoordinator,
## located by capability (a node exposing a StockMarket `market`) so the terminal
## reads + trades the same prices that hits and wanted spikes move. Cached once found;
## null if no live market is in the scene. Mirrors HitContractBoard's discovery.
func _market() -> StockMarket:
	if _market_cache != null:
		return _market_cache
	for node: Node in _market_candidates():
		var book: Variant = node.get("market")
		if book is StockMarket:
			_market_cache = book
			break
	return _market_cache


func _market_candidates() -> Array:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return []
	return tree.root.find_children("*", "Node", true, false)
