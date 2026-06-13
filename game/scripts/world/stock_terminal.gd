class_name StockTerminal
extends Area3D
## A walk-up brokerage terminal for ONE company: step in flat and you BUY `shares`
## (if affordable); step in already holding that company and you SELL your whole
## position at the current price (cash to PlayerStats). Prices move on in-world
## events — most notably a HitContractBoard hit — so the loop is: buy the rival's
## competitor, do the hit, come back and sell the spike.
##
## Trades into the scene's ONE live market — the `MarketEventCoordinator` published
## in group "stock_market" (it exposes the StockMarket as `.market`) — so the shares
## you buy here are the ones a hit's shock revalues. Self-wires by group (player /
## player_stats / stock_market). Needs a CollisionShape3D child; watches the
## player's collision layer (2). Verified in tests/stock_terminal_probe.gd.

signal bought(company_id: String, qty: int, cost: int)
signal sold(company_id: String, qty: int, proceeds: int)

## Hard cap on a single order so a misconfigured/huge `shares` can't overflow
## price * qty into a negative cost.
const MAX_SHARES: int = 100000

## The company this terminal trades (must exist in StockMarket's roster).
@export var company_id: String = "fruit_systems"
## Shares bought per visit when the player holds none.
@export var shares: int = 10


func _ready() -> void:
	shares = clampi(shares, 0, MAX_SHARES)
	add_to_group("stock_terminal")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var owner_node := get_tree().get_first_node_in_group("stock_market")
	if owner_node == null or not ("market" in owner_node):
		return
	var market_var: Variant = owner_node.market
	if not (market_var is StockMarket):
		return
	var market: StockMarket = market_var
	if not market.has_company(company_id):
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not ("money" in stats):
		return
	var held := market.shares_held(company_id)
	if held > 0:
		_sell(market, stats, held)
	else:
		_buy(market, stats)


## Sell the player's whole position at the current price. Requires PlayerStats can
## be paid BEFORE the shares leave the portfolio (no unpaid sale).
func _sell(market: StockMarket, stats: Node, qty: int) -> void:
	if not stats.has_method("add_money"):
		return
	# Confirm the sale is worth something BEFORE sell() erases the position, so a
	# zero-value sale can never destroy shares without paying.
	if market.price(company_id) * qty <= 0:
		return
	var result := market.sell(company_id, qty)
	if not result.get("success", false):
		return
	stats.add_money(int(result["proceeds"]))
	sold.emit(company_id, qty, int(result["proceeds"]))


## Buy `shares` at the current price (charged via PlayerStats). Computes the cost
## up front and refuses a non-positive cost so a bad price/qty can't grant free
## shares.
func _buy(market: StockMarket, stats: Node) -> void:
	if shares <= 0 or not stats.has_method("spend_money"):
		return
	var cost := market.price(company_id) * shares
	if cost <= 0:
		return
	var result := market.buy(company_id, shares, int(stats.money))
	if not result.get("success", false):
		return
	stats.spend_money(int(result["cost"]))
	bought.emit(company_id, shares, int(result["cost"]))
