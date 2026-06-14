class_name BusinessVentureController
extends Node
## Brings the previously-unwired BusinessVenture model to life: owns the player's ONE
## operated-business empire, runs PRODUCTION on an in-game-day clock (accrue converts
## stocked supply into product while you're away), resolves every money op against
## PlayerStats, and prices each cash-out with LIVE police heat — a hot operation sells its
## product at a discount (reads the wanted node's stars). Self-wires by group
## ("business_venture"); BusinessFront zones acquire/cash-out against this one shared owner
## (one controller, many fronts — like GangTerritoryController + TurfZone). Owns ONE
## BusinessVenture (tests/unit/test_business_venture.gd); verified business_venture_probe.gd.

signal venture_acquired(id: String)
signal cashed_out(id: String, proceeds: int, sold: int)

## Floor on the day period and cap on days advanced per frame, so a tiny seconds_per_day
## or a lag-spike delta can't run thousands of production ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0
## Wanted stars at which the operation is fully hot (heat == 1.0).
const MAX_HEAT_STARS: float = 5.0

## Market demand multiplier for cash-outs (neutral 1.0; a live DistrictEconomy node could
## feed this later — the model clamps it to its [0.5, 2.0] band regardless).
@export var sell_demand: float = 1.0
## Real seconds per in-game day for the production clock (<=0 pauses it).
@export var seconds_per_day: float = 90.0

var _empire: BusinessVenture
var _day_accum: float = 0.0


func _ready() -> void:
	_empire = BusinessVenture.new()
	add_to_group("business_venture")


func _process(delta: float) -> void:
	if seconds_per_day <= 0.0 or _empire == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_empire.accrue(1.0)


# --- Wallet-resolved operations ----------------------------------------------


## Take over a venture, paying `cost` from PlayerStats. Guards a positive cost AND a wallet
## that can cover it BEFORE the model mutates _owned, so a free/short takeover is impossible
## even if a front's acquire_cost is misconfigured to 0 (the model would mark it owned but
## spend_money(0) is a no-op). Returns true on success.
func try_acquire(id: String, cost: int) -> bool:
	if cost <= 0:
		return false
	var stats := _stats()
	if stats == null or not stats.has_method("spend_money") or int(stats.money) < cost:
		return false
	var result := _empire.acquire(id, cost, int(stats.money))
	if not result["success"]:
		return false
	if not stats.spend_money(cost):
		return false
	venture_acquired.emit(id)
	return true


## Restock raw materials, paying only for what fits under the supply ceiling. Returns the
## money actually spent (0 if nothing was bought).
func try_buy_supplies(id: String, units: int, unit_cost: int) -> int:
	var stats := _stats()
	if stats == null or not stats.has_method("spend_money"):
		return 0
	var result := _empire.buy_supplies(id, units, unit_cost, int(stats.money))
	if not result["success"]:
		return 0
	var spent := int(result["cost"])
	if not stats.spend_money(spent):
		return 0
	return spent


## Hire one worker (raises production rate), bounded by the venture's max_staff.
func hire(id: String) -> bool:
	return _empire.hire(id) if _empire != null else false


## Sell the entire accrued stockpile at the live heat-discounted price, paying proceeds into
## PlayerStats. Guards add_money BEFORE the model removes product so a missing wallet can't
## burn the stockpile. Returns proceeds (0 if nothing sold).
func cash_out(id: String) -> int:
	var stats := _stats()
	if stats == null or not stats.has_method("add_money"):
		return 0
	var units := int(floor(_empire.product_in(id)))
	if units <= 0:
		return 0
	var result := _empire.sell(id, units, sell_demand, _live_heat())
	if not result["success"]:
		return 0
	var proceeds := int(result["proceeds"])
	stats.add_money(proceeds)
	cashed_out.emit(id, proceeds, int(result["sold"]))
	return proceeds


# --- Queries (passthroughs for fronts / HUD) ---------------------------------


func owns(id: String) -> bool:
	return _empire != null and _empire.owns(id)


func product_in(id: String) -> float:
	return _empire.product_in(id) if _empire != null else 0.0


func supply_in(id: String) -> float:
	return _empire.supply_in(id) if _empire != null else 0.0


func staff_in(id: String) -> int:
	return _empire.staff_in(id) if _empire != null else 0


func total_product() -> int:
	return _empire.total_product() if _empire != null else 0


func gross_earned() -> int:
	return _empire.gross_earned() if _empire != null else 0


# --- Internal ----------------------------------------------------------------


func _stats() -> Node:
	return get_tree().get_first_node_in_group("player_stats")


## Police heat in [0,1] from the live wanted stars (a hot op sells at a discount).
func _live_heat() -> float:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_method("stars"):
		return clampf(float(wanted.stars()) / MAX_HEAT_STARS, 0.0, 1.0)
	return 0.0
