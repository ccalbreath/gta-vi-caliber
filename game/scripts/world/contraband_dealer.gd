class_name ContrabandDealer
extends Node3D
## A walk-in black-market loop: buy contraband cheap at the Dealer zone, carry it,
## then sell it dear at the Fence zone across the strip — the classic buy-low /
## sell-high arbitrage. Consumes the tested ContrabandMarket model and self-wires by
## group (player / player_stats), so it needs no plumbing beyond two Area3D +
## CollisionShape3D children named "DealZone" and "FenceZone".
##
## Each zone fires once per entry (like PaySprayShop): stepping into DealZone buys
## `buy_qty` of `good_id` at the deal district's price if affordable; stepping into
## FenceZone sells everything carried at the fence district's (dearer) price. Pricing
## / arbitrage curves live in the unit-tested ContrabandMarket; this node's wiring is
## exercised by tests/contraband_market_probe.gd. Original system — no affiliation
## with any commercial title.

## Fired when the player buys at the dealer (good, qty, total cost paid).
signal contraband_bought(good: String, qty: int, cost: int)
## Fired when the player fences carried goods (good, qty, total revenue).
signal contraband_sold(good: String, qty: int, revenue: int)

## The good traded here (must exist in ContrabandMarket's catalogue).
@export var good_id: String = "electronics"
## Units bought per step into the dealer zone.
@export var buy_qty: int = 1
## District the dealer prices buys in (cheaper). A different fence district id gives a
## different, higher price multiplier — that gap is the arbitrage profit. (south_beach
## hashes to a low multiplier, wynwood to a high one, so this route nets a profit;
## tests/contraband_market_probe.gd guards that the route stays profitable.)
@export var deal_district: String = "south_beach"
## District the fence prices sales in (dearer).
@export var fence_district: String = "wynwood"

## The live market. Public so a price-board UI can read prices / carried stock.
var market: ContrabandMarket

var _deal_zone: Area3D
var _fence_zone: Area3D
var _stats: Node = null


func _init() -> void:
	market = ContrabandMarket.new()


func _ready() -> void:
	add_to_group("contraband_dealer")
	_deal_zone = get_node_or_null("DealZone") as Area3D
	_fence_zone = get_node_or_null("FenceZone") as Area3D
	if _deal_zone != null:
		# player.gd puts the player body on collision layer 2; watch for it.
		_deal_zone.collision_mask |= 2
		_deal_zone.body_entered.connect(_on_deal_entered)
	if _fence_zone != null:
		_fence_zone.collision_mask |= 2
		_fence_zone.body_entered.connect(_on_fence_entered)


func _on_deal_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var stats := _player_stats()
	if stats == null or not ("money" in stats):
		return
	var result: Dictionary = market.buy(good_id, buy_qty, deal_district, int(stats.money))
	if not result.get("success", false):
		return
	if stats.has_method("spend_money") and stats.spend_money(int(result["cost"])):
		market.carry(good_id, buy_qty)
		contraband_bought.emit(good_id, buy_qty, int(result["cost"]))


func _on_fence_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var qty: int = market.carried(good_id)
	if qty <= 0:
		return
	var stats := _player_stats()
	if stats == null or not stats.has_method("add_money"):
		return
	var revenue: int = market.sell(good_id, qty, fence_district)
	if revenue <= 0:
		return
	market.drop(good_id, qty)
	stats.add_money(revenue)
	contraband_sold.emit(good_id, qty, revenue)


func _player_stats() -> Node:
	if _stats == null or not is_instance_valid(_stats):
		_stats = get_tree().get_first_node_in_group("player_stats")
	return _stats
