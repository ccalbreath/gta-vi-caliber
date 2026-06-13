class_name Fence
extends RefCounted
## The fence — where stolen goods become cash, closing the loot→money loop (robberies
## and heists drop valuables; this is how you sell them). A fence pays a fraction of
## an item's worth, and pays LESS for HOT goods (a watch lifted an hour ago is
## radioactive); let the heat cool over a few days and the same piece fetches more.
## So there's a real choice: dump it now for quick cash, or sit on it and sell clean.
##
## Distinct from `ShopModel` (buying a catalogue), `ChopShop` (vehicles), and
## `ContrabandMarket` (drug arbitrage): this is the stolen-VALUABLES sink. Pure +
## deterministic, no wallet coupling (the caller banks the proceeds), unit-tested
## headless (tests/unit/test_fence.gd). Persisted via to_dict/from_dict.

## Base fraction of an item's value the fence pays (their cut is the rest).
const FENCE_RATE: float = 0.6
## How much a fully-hot item's quote is docked (risk pricing).
const HOT_PENALTY: float = 0.3
## Heat shed per day as goods cool off.
const COOL_PER_DAY: float = 0.5

var _items: Dictionary = {}  # id -> {category, value, heat}

# --- Inventory ---------------------------------------------------------------


## Take in a freshly stolen valuable (enters fully hot). Fails on a dup/empty id.
func add_loot(id: String, category: String, value: int) -> bool:
	var clean := id.strip_edges()
	if clean.is_empty() or value <= 0 or _items.has(clean):
		return false
	_items[clean] = {"category": category, "value": value, "heat": 1.0}
	return true


func has_item(id: String) -> bool:
	return _items.has(id)


func inventory_count() -> int:
	return _items.size()


func inventory_value() -> int:
	var total := 0
	for id in _items:
		total += int(_items[id]["value"])
	return total


func item_heat(id: String) -> float:
	if not _items.has(id):
		return 0.0
	return _items[id]["heat"]


# --- Pricing -----------------------------------------------------------------


## What the fence pays for an item right now: base rate, docked by how hot it is.
func fence_quote(id: String) -> int:
	if not _items.has(id):
		return 0
	var value: float = _items[id]["value"]
	var heat: float = _items[id]["heat"]
	return int(floor(value * FENCE_RATE * (1.0 - heat * HOT_PENALTY)))


# --- Cooling + selling -------------------------------------------------------


## Goods cool off over time, raising what they'll fetch.
func cool(days: float) -> void:
	if days <= 0.0:
		return
	for id in _items:
		_items[id]["heat"] = maxf(float(_items[id]["heat"]) - COOL_PER_DAY * days, 0.0)


## Sell one item at its current quote and remove it. Returns {success, proceeds}.
func sell(id: String) -> Dictionary:
	if not _items.has(id):
		return {"success": false, "proceeds": 0}
	var proceeds := fence_quote(id)
	_items.erase(id)
	return {"success": true, "proceeds": proceeds}


## Sell the whole stash at current quotes. Returns the total proceeds.
func sell_all() -> int:
	var total := 0
	for id in _items.keys():
		total += fence_quote(id)
	_items.clear()
	return total


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"items": _items.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_items.clear()
	var saved: Dictionary = data.get("items", {})
	for id in saved:
		var it: Dictionary = saved[id]
		_items[str(id)] = {
			"category": str(it.get("category", "")),
			"value": maxi(int(it.get("value", 0)), 0),
			"heat": clampf(float(it.get("heat", 1.0)), 0.0, 1.0),
		}
