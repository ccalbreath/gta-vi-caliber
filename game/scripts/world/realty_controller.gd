class_name RealtyController
extends Node
## Self-wiring real-estate desk — turns a PropertyFlip model into a playable BUY → RENOVATE → SELL
## loop. Joins group "realty" so a PropertyListing (Area3D) can drive each property one stage per
## visit: it charges the purchase + renovation to PlayerStats up front, then banks the sale on the
## final visit for a one-time appreciation profit. Distinct from the passive-income property desk;
## this is a terminal flip, not an income stream. Runtime-verified headless
## (tests/property_flip_probe.gd).

signal bought(id: String, price: int)
signal renovated(id: String, cost: int)
signal sold(id: String, proceeds: int, profit: int)

var _flip: PropertyFlip = null


func _init(flip: PropertyFlip = null) -> void:
	_flip = flip if flip != null else PropertyFlip.new()


func _ready() -> void:
	add_to_group("realty")


# --- Queries (for the listing / HUD) -----------------------------------------


func state_of(id: String) -> String:
	return _flip.state_of(id) if _flip != null else ""


func price_of(id: String) -> int:
	return _flip.price_of(id) if _flip != null else 0


func reno_cost_of(id: String) -> int:
	return _flip.reno_cost_of(id) if _flip != null else 0


func profit_of(id: String) -> int:
	return _flip.profit_of(id) if _flip != null else 0


# --- Play --------------------------------------------------------------------


## Advance one stage of the flip for `id` (buy → renovate → sell), charging or banking against
## PlayerStats as appropriate. Returns the resulting state ("" if the property is unknown).
func advance(id: String) -> String:
	if _flip == null or not _flip.has_property(id):
		return ""
	var stats := get_tree().get_first_node_in_group("player_stats")
	var state := _flip.state_of(id)
	if state == PropertyFlip.STATE_AVAILABLE:
		return _try_buy(id, stats)
	if state == PropertyFlip.STATE_OWNED:
		return _try_renovate(id, stats)
	if state == PropertyFlip.STATE_RENOVATED:
		return _try_sell(id, stats)
	return state


func _try_buy(id: String, stats: Node) -> String:
	var price := _flip.price_of(id)
	if price <= 0 or stats == null or not stats.has_method("spend_money"):
		return _flip.state_of(id)
	if not stats.spend_money(price):
		return _flip.state_of(id)
	_flip.buy(id)
	bought.emit(id, price)
	return _flip.state_of(id)


func _try_renovate(id: String, stats: Node) -> String:
	var cost := _flip.reno_cost_of(id)
	if cost <= 0 or stats == null or not stats.has_method("spend_money"):
		return _flip.state_of(id)
	if not stats.spend_money(cost):
		return _flip.state_of(id)
	_flip.renovate(id)
	renovated.emit(id, cost)
	return _flip.state_of(id)


func _try_sell(id: String, stats: Node) -> String:
	if stats == null or not stats.has_method("add_money"):
		return _flip.state_of(id)
	# Mutate first, bank only on a real transition — same spend-before/commit shape as buy/renovate.
	var proceeds := _flip.sell(id)
	if proceeds <= 0:
		return _flip.state_of(id)
	var profit := _flip.profit_of(id)
	stats.add_money(proceeds)
	sold.emit(id, proceeds, profit)
	return _flip.state_of(id)
