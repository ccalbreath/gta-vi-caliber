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
## Fired when a fence sale goes wrong and the player is BUSTED (good, qty seized).
## No payout lands; the wanted system is poked instead.
signal contraband_busted(good: String, qty: int)

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

## Base chance a fence sale turns into a bust BEFORE the police-proximity scaling and
## the carried-load penalty ContrabandMarket.bust_risk folds in. Feeds market.bust_risk
## as its base_risk; with no police near the fence the bust chance is forced to 0.
@export var bust_base_risk: float = 0.15
## How close (metres) a node in group `police` must be to the fence zone to add heat to
## a sale. No police inside this radius => no bust, ever (the original sell path).
@export var police_scan_radius: float = 40.0

## The live market. Public so a price-board UI can read prices / carried stock.
var market: ContrabandMarket

var _deal_zone: Area3D
var _fence_zone: Area3D
var _stats: Node = null
## Node-owned, seedable rng so the bust roll is deterministic under test (set_seed).
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


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
	resolve_fence_sale()


## Run the full fence-sale decision and apply its outcome, returning
## {"busted": bool, "revenue": int}. Public + signal-free so a probe can drive it
## deterministically (seed via set_seed). Sells everything carried of `good_id` at the
## fence district's price; near police that sale carries a bust risk that voids the
## payout and raises the player's wanted level instead. With no police inside
## police_scan_radius the path is byte-identical to the original always-pay sell.
func resolve_fence_sale() -> Dictionary:
	var qty: int = market.carried(good_id)
	if qty <= 0:
		return {"busted": false, "revenue": 0}
	var stats := _player_stats()
	if stats == null or not stats.has_method("add_money"):
		return {"busted": false, "revenue": 0}
	var revenue: int = market.sell(good_id, qty, fence_district)
	if revenue <= 0:
		return {"busted": false, "revenue": 0}
	market.drop(good_id, qty)
	var risk := clampf(market.bust_risk(revenue, bust_base_risk) * _police_factor(), 0.0, 1.0)
	if risk > 0.0 and _rng.randf() < risk:
		return _bust(qty)
	stats.add_money(revenue)
	contraband_sold.emit(good_id, qty, revenue)
	return {"busted": false, "revenue": revenue}


## Apply a bust: no payout, poke the wanted system (group `wanted`) if present, and
## announce the seizure. The contraband was already dropped by the caller.
func _bust(qty: int) -> Dictionary:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_method("report_crime"):
		wanted.report_crime(false)
	contraband_busted.emit(good_id, qty)
	return {"busted": true, "revenue": 0}


## How much heat the police near the fence zone add to a sale: 0 when none are inside
## police_scan_radius (so the original sell path is untouched), climbing with both how
## many cops are near and how close they are. Scales market.bust_risk into the real risk.
func _police_factor() -> float:
	if _fence_zone == null:
		return 0.0
	var here: Vector3 = _fence_zone.global_position
	var radius: float = maxf(police_scan_radius, 0.001)
	var factor: float = 0.0
	for cop: Variant in get_tree().get_nodes_in_group("police"):
		var node := cop as Node3D
		if node == null:
			continue
		var dist: float = node.global_position.distance_to(here)
		if dist <= police_scan_radius:
			factor += 1.0 - dist / radius
	return factor


## Deterministic-test helper: reseed the bust roll so a probe gets repeatable outcomes.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func _player_stats() -> Node:
	if _stats == null or not is_instance_valid(_stats):
		_stats = get_tree().get_first_node_in_group("player_stats")
	return _stats
