class_name BlackMarketStall
extends Area3D
## A walk-up black-market dealer for ONE contraband good in ONE district. Step in
## carrying that good and the dealer buys your stash off you at this district's
## price (cash to PlayerStats); step in empty-handed and you buy a parcel (if you
## can afford it). Districts pay different rates, so the loop is arbitrage: buy in a
## cheap district, carry it, sell in a pricey one.
##
## Trades into the SHARED ContrabandController inventory (group "contraband") so a
## parcel bought here can be carried to another stall. Self-wires by group (player /
## player_stats / contraband). Needs a CollisionShape3D child; watches the player's
## collision layer (2). Verified end-to-end in tests/black_market_probe.gd.

signal bought(good: String, qty: int, cost: int)
signal sold(good: String, qty: int, proceeds: int)

## Hard cap on a single parcel so a misconfigured/huge buy_qty can't overflow
## price * qty into a negative cost (which would otherwise mint money).
const MAX_BUY_QTY: int = 1000

## The contraband this dealer trades (must exist in ContrabandMarket's catalogue).
@export var good: String = "product"
## District this stall sits in — sets the local price via the market's multiplier.
@export var district_id: String = "downtown"
## Units bought per visit when the player arrives empty-handed.
@export var buy_qty: int = 5


func _ready() -> void:
	buy_qty = clampi(buy_qty, 0, MAX_BUY_QTY)
	add_to_group("black_market")
	collision_mask |= 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var controller := get_tree().get_first_node_in_group("contraband")
	if controller == null or not controller.has_method("market"):
		return
	var market: ContrabandMarket = controller.market()
	if market == null or not market.has_good(good):
		return
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not ("money" in stats):
		return
	# A stall only knows its own good: carrying THIS good sells the stash here;
	# otherwise the player buys a parcel (carrying a *different* good still buys).
	var held := market.carried(good)
	if held > 0:
		_sell(market, stats, held)
	else:
		_buy(market, stats)


## Fence the player's whole stash of this good at the local price. Requires
## PlayerStats can be paid BEFORE the goods leave the inventory (no unpaid drop).
func _sell(market: ContrabandMarket, stats: Node, qty: int) -> void:
	if not stats.has_method("add_money"):
		return
	var proceeds := market.sell(good, qty, district_id)
	if proceeds <= 0:
		return
	market.drop(good, qty)
	stats.add_money(proceeds)
	sold.emit(good, qty, proceeds)


## Buy a parcel at the local price (charged via PlayerStats) and load it onto the
## player. No-op if unaffordable or the player can't be charged.
func _buy(market: ContrabandMarket, stats: Node) -> void:
	if buy_qty <= 0 or not stats.has_method("spend_money"):
		return
	var result := market.buy(good, buy_qty, district_id, int(stats.money))
	if not result.get("success", false):
		return
	# A valid parcel always costs > 0; reject a non-positive cost (overflow / garbage)
	# so a charge can never credit the player.
	var cost := int(result["cost"])
	if cost <= 0:
		return
	stats.spend_money(cost)
	market.carry(good, buy_qty)
	bought.emit(good, buy_qty, cost)
