class_name PropertyFlip
extends RefCounted
## Pure real-estate FLIP model — buy a run-down property, renovate it, sell it for the appreciated
## value. The hook is the three-stage BUY → RENOVATE → SELL lifecycle: each property flips exactly
## once for a one-time appreciation profit (resale − price − renovation). Distinct from
## PropertyOwnership (buy once, then PASSIVE daily income) and BusinessVenture (ongoing
## supply → product → sell production) by being a terminal one-shot trade. No nodes, no wallet
## coupling (the caller charges the purchase + renovation and banks the sale). Unit-tested headless
## (tests/unit/test_property_flip.gd).

const STATE_AVAILABLE: String = "available"
const STATE_OWNED: String = "owned"
const STATE_RENOVATED: String = "renovated"
const STATE_SOLD: String = "sold"

## id -> {name, price, reno_cost, resale, state}. Insertion-ordered.
var _listings: Dictionary = {}


func _init(listings: Array = []) -> void:
	var source: Array = listings if not listings.is_empty() else default_listings()
	for entry: Variant in source:
		_register(entry)


## Built-in market — most are profitable flips, but `swamp_shack` is a money-loser (its resale
## doesn't clear the purchase + renovation). Read `profit_of(id)` before you commit: a flip is a
## real decision, not free money.
static func default_listings() -> Array:
	return [
		{
			"id": "harbor_loft",
			"name": "Harbor Loft",
			"price": 40000,
			"reno_cost": 25000,
			"resale": 90000
		},
		{
			"id": "vice_bungalow",
			"name": "Vice Bungalow",
			"price": 75000,
			"reno_cost": 40000,
			"resale": 150000
		},
		{
			"id": "downtown_condo",
			"name": "Downtown Condo",
			"price": 120000,
			"reno_cost": 60000,
			"resale": 220000
		},
		{
			"id": "swamp_shack",
			"name": "Swamp Shack",
			"price": 50000,
			"reno_cost": 30000,
			"resale": 60000  # a dud — flip this and you lose 20k
		},
	]


# --- Queries -----------------------------------------------------------------


func count() -> int:
	return _listings.size()


func has_property(id: String) -> bool:
	return _listings.has(id)


func state_of(id: String) -> String:
	return str(_listings[id]["state"]) if _listings.has(id) else ""


func price_of(id: String) -> int:
	return int(_listings[id]["price"]) if _listings.has(id) else 0


func reno_cost_of(id: String) -> int:
	return int(_listings[id]["reno_cost"]) if _listings.has(id) else 0


func resale_of(id: String) -> int:
	return int(_listings[id]["resale"]) if _listings.has(id) else 0


## What the flip nets if carried through: resale − price − renovation. Can be negative (a dud).
func profit_of(id: String) -> int:
	if not _listings.has(id):
		return 0
	return resale_of(id) - price_of(id) - reno_cost_of(id)


func is_owned(id: String) -> bool:
	return state_of(id) == STATE_OWNED


func is_renovated(id: String) -> bool:
	return state_of(id) == STATE_RENOVATED


func is_sold(id: String) -> bool:
	return state_of(id) == STATE_SOLD


# --- Mutations ---------------------------------------------------------------


## Take ownership. Only an AVAILABLE property can be bought; returns whether it transitioned.
## The caller charges price_of(id) BEFORE calling this (no wallet coupling here).
func buy(id: String) -> bool:
	if state_of(id) != STATE_AVAILABLE:
		return false
	_listings[id]["state"] = STATE_OWNED
	return true


## Renovate an OWNED property. Returns whether it transitioned. Caller charges reno_cost_of(id).
func renovate(id: String) -> bool:
	if state_of(id) != STATE_OWNED:
		return false
	_listings[id]["state"] = STATE_RENOVATED
	return true


## Sell a RENOVATED property for its resale value (returned). Marks it SOLD (terminal — a property
## flips exactly once). Returns 0 if it wasn't renovated yet (nothing sold).
func sell(id: String) -> int:
	if state_of(id) != STATE_RENOVATED:
		return 0
	_listings[id]["state"] = STATE_SOLD
	return resale_of(id)


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for id: String in _listings:
		states[id] = _listings[id]["state"]
	return {"state": states}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var stored: Variant = (data as Dictionary).get("state")
	if not (stored is Dictionary):
		return
	var states: Dictionary = stored
	for key: Variant in states:
		var id: String = str(key)
		if _listings.has(id) and _is_valid_state(str(states[key])):
			_listings[id]["state"] = str(states[key])


# --- Internal ----------------------------------------------------------------


func _is_valid_state(state: String) -> bool:
	return state in [STATE_AVAILABLE, STATE_OWNED, STATE_RENOVATED, STATE_SOLD]


func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _listings.has(id):
		return
	var price: int = int(row.get("price", 0))
	var reno_cost: int = int(row.get("reno_cost", 0))
	var resale: int = int(row.get("resale", 0))
	# Reject free acquisitions / zero-work / zero-value rows — a 0-price flip would print money.
	if price <= 0 or reno_cost <= 0 or resale <= 0:
		return
	_listings[id] = {
		"name": str(row.get("name", id)),
		"price": price,
		"reno_cost": reno_cost,
		"resale": resale,
		"state": STATE_AVAILABLE,
	}
