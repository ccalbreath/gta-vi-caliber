class_name DealerNetwork
extends RefCounted
## A street drug-dealing EMPIRE — the management layer above personal contraband
## arbitrage. Recruit dealers onto district corners, keep them supplied with
## product, and each cycle they move stock for passive revenue scaled by local
## demand. But a hot city raids your corners: busts scale with police heat and
## fall with how much of the turf you control, so expanding faster than you can
## protect just feeds the evidence locker.
##
## Distinct from `ContrabandMarket` (carry-and-sell arbitrage) and `BusinessVenture`
## (produce-and-sell a property): this is the dealer/territory network. Pure,
## deterministic (busts are a designed fraction of the network, not an RNG roll, so
## it unit-tests headless — tests/unit/test_dealer_network.gd). A world controller
## recruits dealers (charging the wallet), feeds `supply()` from production/
## contraband, calls `run_cycle()` on a day tick with the district demand, the
## player's `WantedSystem` heat (0..1) and `GangTerritory` control (0..1), credits
## the returned revenue and applies the bust heat. Persisted via to_dict/from_dict.

## Default units a dealer can move per cycle.
const DEFAULT_THROUGHPUT: int = 10
## Most of the network that can be lost to busts in a single cycle (at max heat).
const MAX_BUST_FRACTION: float = 0.5
## WantedSystem heat severity added per dealer busted.
const HEAT_PER_BUST: int = 1

var _dealers: Array = []  # each {id, district, throughput}
var _stock: int = 0

# --- Roster ------------------------------------------------------------------


func recruit(id: String, district: String, throughput: int = DEFAULT_THROUGHPUT) -> bool:
	var clean_id := id.strip_edges()
	if clean_id.is_empty() or throughput <= 0 or has_dealer(clean_id):
		return false
	_dealers.append({"id": clean_id, "district": district, "throughput": throughput})
	return true


func fire(id: String) -> bool:
	for i in _dealers.size():
		if _dealers[i]["id"] == id:
			_dealers.remove_at(i)
			return true
	return false


func has_dealer(id: String) -> bool:
	for d in _dealers:
		if d["id"] == id:
			return true
	return false


func network_size() -> int:
	return _dealers.size()


func throughput_total() -> int:
	var total := 0
	for d in _dealers:
		total += int(d["throughput"])
	return total


# --- Product -----------------------------------------------------------------


func supply(units: int) -> int:
	if units > 0:
		_stock += units
	return _stock


func product_stock() -> int:
	return _stock


# --- Enforcement -------------------------------------------------------------


## Fraction of the network lost to busts this cycle: rises with police heat, falls
## with turf control (your corners are safer where you run the streets).
func bust_rate(heat01: float, turf_control01: float) -> float:
	var pressure := clampf(heat01, 0.0, 1.0) - clampf(turf_control01, 0.0, 1.0)
	return clampf(pressure, 0.0, 1.0) * MAX_BUST_FRACTION


# --- Cycle -------------------------------------------------------------------


## Run one selling cycle. Dealers move up to the network throughput × demand,
## bounded by stock; then a designed fraction get busted (heat vs turf). Returns
## {units_sold, revenue, busts, heat_added, stock_left, network_size}.
func run_cycle(
	demand01: float, unit_price: int, heat01: float, turf_control01: float
) -> Dictionary:
	var demand := clampf(demand01, 0.0, 1.0)
	var capacity := int(floor(float(throughput_total()) * demand))
	var units_sold: int = mini(capacity, _stock)
	_stock -= units_sold
	var revenue: int = units_sold * maxi(unit_price, 0)

	var busts: int = int(floor(float(network_size()) * bust_rate(heat01, turf_control01)))
	for _i in busts:
		if not _dealers.is_empty():
			_dealers.remove_at(0)  # the most-established corners get raided first
	return {
		"units_sold": units_sold,
		"revenue": revenue,
		"busts": busts,
		"heat_added": busts * HEAT_PER_BUST,
		"stock_left": _stock,
		"network_size": network_size(),
	}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"dealers": _dealers.duplicate(true), "stock": _stock}


func from_dict(data: Dictionary) -> void:
	_dealers.clear()
	for d in data.get("dealers", []):
		if typeof(d) == TYPE_DICTIONARY and not str(d.get("id", "")).is_empty():
			(
				_dealers
				. append(
					{
						"id": str(d["id"]),
						"district": str(d.get("district", "")),
						"throughput": int(d.get("throughput", DEFAULT_THROUGHPUT)),
					}
				)
			)
	_stock = maxi(int(data.get("stock", 0)), 0)
