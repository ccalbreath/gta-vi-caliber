class_name BusinessVentureHub
extends Node3D
## A walk-up business you can take over and OPERATE: face it, press interact, and
## the first press ACQUIRES the venture (charged to PlayerStats); every later press
## CASHES OUT the accrued stockpile (credited to PlayerStats). Between presses the
## hub ticks the venture over real time so product piles up while you do other
## things. Consumes the unit-tested BusinessVenture model (the active "run the
## racket" economy layer atop PropertyOwnership's passive income) and self-wires by
## group (interactables / player_stats) — no plumbing beyond dropping the node.
##
## The Interactable contract (see Interaction): joins group "interactables" and
## answers interact_prompt() + interact(player). All money is resolved against the
## live wallet; BusinessVenture itself never touches PlayerStats.

## Fired when the player takes over the business (id, cost charged).
signal business_acquired(id: String, cost: int)
## Fired when the player cashes out the stockpile (total proceeds credited).
signal business_collected(amount: int)

## BusinessVenture catalogue id this hub operates (must exist in the catalogue).
@export var business_id: String = "coke_lab"
## Acquisition price charged to the wallet on the first interact.
@export var acquire_cost: int = 25000
## Per-unit raw-supply price; supplies are bought on takeover so production can run.
@export var supply_unit_cost: int = 50
## Raw-supply units stocked on takeover (seeds the supply→product conversion).
@export var supply_units: int = 200
## Real seconds that map to one in-world "day" of production accrual.
@export var seconds_per_day: float = 6.0
## Market demand multiplier passed to sell() (DistrictEconomy.desirability stand-in).
@export var demand: float = 1.0
## Police-heat discount in 0..1 passed to sell() (WantedSystem stand-in).
@export var heat: float = 0.0
## Stockpile units cashed out per interact (large so a full cash-out clears it).
@export var sell_batch: int = 100000

## The live business model. Public so a manage/HUD UI can read its operational state.
var venture: BusinessVenture

var _stats: Node = null


func _init() -> void:
	venture = BusinessVenture.new()


func _ready() -> void:
	add_to_group("interactables")


## Drive the owned venture forward in real time so product accrues between visits.
func _process(delta: float) -> void:
	if seconds_per_day > 0.0 and venture.owns(business_id):
		venture.accrue(delta / seconds_per_day)


## HUD hint: invites a takeover before ownership, a cash-out after.
func interact_prompt() -> String:
	return "Cash out business" if venture.owns(business_id) else "Buy business"


## First press buys the business; every later press cashes out the stockpile.
func interact(_player: Node) -> void:
	if venture.owns(business_id):
		_collect()
	else:
		_acquire()


## Charge the takeover cost, mark the venture owned, and stock raw supplies so the
## production loop has something to convert. No-op if it can't be charged.
func _acquire() -> void:
	var stats := _player_stats()
	if stats == null or not ("money" in stats):
		return
	var result: Dictionary = venture.acquire(business_id, acquire_cost, int(stats.money))
	if not result.get("success", false) or not stats.has_method("spend_money"):
		return
	if not stats.spend_money(int(result["cost"])):
		return
	venture.buy_supplies(business_id, supply_units, supply_unit_cost, int(stats.money))
	business_acquired.emit(business_id, int(result["cost"]))


## Sell the accrued product at the demand/heat-adjusted price and bank the proceeds.
func _collect() -> void:
	var result: Dictionary = venture.sell(business_id, sell_batch, demand, heat)
	if not result.get("success", false):
		return
	var proceeds: int = int(result["proceeds"])
	var stats := _player_stats()
	if proceeds <= 0 or stats == null or not stats.has_method("add_money"):
		return
	stats.add_money(proceeds)
	business_collected.emit(proceeds)


## Advance production by a real-time span (exposed so a probe can tick deterministically).
func tick(delta: float) -> void:
	if delta > 0.0 and seconds_per_day > 0.0 and venture.owns(business_id):
		venture.accrue(delta / seconds_per_day)


## Whether this hub's venture is owned, for a HUD readout.
func owns_business() -> bool:
	return venture != null and venture.owns(business_id)


## Current accrued stockpile in whole units, for a HUD readout.
func stockpile() -> int:
	return int(floor(venture.product_in(business_id))) if venture != null else 0


func _player_stats() -> Node:
	if _stats == null or not is_instance_valid(_stats):
		_stats = get_tree().get_first_node_in_group("player_stats")
	return _stats
