class_name DrugLab
extends RefCounted
## A product LAB — the manufacturing SOURCE of the drug-empire vertical
## (DrugLab cooks → DealerNetwork distributes → MoneyLaundering washes the cash).
## You start a batch, let it cook over time, and collect units at a PURITY set by
## your equipment tier and how greedily you sized the batch (rushing a huge cook
## drops purity). While a batch is cooking the lab is exposed: raid risk climbs
## with batch size and the city's heat. Collected product is inventory you
## withdraw to supply your dealers.
##
## Distinct from `BusinessVenture` (which produces-and-SELLS a generic property for
## cash): the lab outputs PRODUCT UNITS + a purity grade meant to feed
## `DealerNetwork.supply()`, not a wallet. Pure + deterministic — unit-tested
## headless (tests/unit/test_drug_lab.gd). A lab trigger starts/collects batches; a
## world tick calls cook(dt); a raid director rolls raid_risk(heat). Persisted via
## to_dict/from_dict.

## Purity for a tier-1 lab cooking a tiny batch, before modifiers.
const BASE_PURITY: float = 0.5
## Purity gained per equipment tier above 1.
const EQUIP_PURITY: float = 0.1
## Purity lost per unit of batch size (rushing a big cook cuts quality).
const SIZE_PENALTY: float = 0.01
## Floor/ceiling on purity.
const PURITY_MIN: float = 0.05
const PURITY_MAX: float = 1.0
## Raid-risk pieces: a base, per-unit exposure, and heat weight.
const BASE_RAID: float = 0.05
const SIZE_RISK: float = 0.005
const HEAT_RISK: float = 0.4
const DEFAULT_COOK_TIME: float = 60.0

var _equipment: int = 1
var _cooking: bool = false
var _batch_size: int = 0
var _progress: float = 0.0
var _cook_time: float = DEFAULT_COOK_TIME
var _inventory: int = 0
var _inventory_purity: float = 0.0


func _init(equipment_tier: int = 1) -> void:
	_equipment = maxi(equipment_tier, 1)


# --- Queries -----------------------------------------------------------------


func equipment_tier() -> int:
	return _equipment


func is_cooking() -> bool:
	return _cooking


func cook_progress() -> float:
	return _progress


func is_batch_done() -> bool:
	return _cooking and _progress >= 1.0


func inventory() -> int:
	return _inventory


func inventory_purity() -> float:
	return _inventory_purity


## Purity a batch of [param size] would yield on this lab's current equipment.
func purity_for(size: int) -> float:
	var p := (
		BASE_PURITY + float(_equipment - 1) * EQUIP_PURITY - float(maxi(size, 0)) * SIZE_PENALTY
	)
	return clampf(p, PURITY_MIN, PURITY_MAX)


## 0..1 raid risk while cooking (rises with batch size + city heat); 0 when idle.
func raid_risk(heat01: float) -> float:
	if not _cooking:
		return 0.0
	return clampf(
		BASE_RAID + float(_batch_size) * SIZE_RISK + clampf(heat01, 0.0, 1.0) * HEAT_RISK, 0.0, 1.0
	)


## Street value per unit at a purity: a cut product is worth less.
func street_value_per_unit(base_price: int, purity: float) -> int:
	return int(round(float(base_price) * (0.5 + clampf(purity, 0.0, 1.0))))


# --- Production --------------------------------------------------------------


## Begin cooking a batch. Fails if a batch is already cooking or the size is <= 0.
func start_batch(size: int, cook_time: float = DEFAULT_COOK_TIME) -> bool:
	if _cooking or size <= 0:
		return false
	_cooking = true
	_batch_size = size
	_progress = 0.0
	_cook_time = maxf(cook_time, 1.0)
	return true


## Advance the cook. Caps at done; collect() is what banks the product.
func cook(dt: float) -> void:
	if not _cooking or dt <= 0.0:
		return
	_progress = minf(_progress + dt / _cook_time, 1.0)


## Bank a finished batch into inventory at its purity (weighted into any existing
## stock), and reset the lab to idle. Returns {units, purity}; a no-op if not done.
func collect() -> Dictionary:
	if not is_batch_done():
		return {"units": 0, "purity": 0.0}
	var units := _batch_size
	var purity := purity_for(units)
	var combined := _inventory + units
	if combined > 0:
		_inventory_purity = (
			(float(_inventory) * _inventory_purity + float(units) * purity) / float(combined)
		)
	_inventory = combined
	_cooking = false
	_batch_size = 0
	_progress = 0.0
	return {"units": units, "purity": purity}


## Pull product out of inventory (to feed DealerNetwork.supply). Returns the units
## actually withdrawn (bounded by stock).
func withdraw(units: int) -> int:
	var taken: int = clampi(units, 0, _inventory)
	_inventory -= taken
	if _inventory == 0:
		_inventory_purity = 0.0
	return taken


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"equipment": _equipment,
		"cooking": _cooking,
		"batch_size": _batch_size,
		"progress": _progress,
		"cook_time": _cook_time,
		"inventory": _inventory,
		"inventory_purity": _inventory_purity,
	}


func from_dict(data: Dictionary) -> void:
	_equipment = maxi(int(data.get("equipment", 1)), 1)
	_cooking = bool(data.get("cooking", false))
	_batch_size = maxi(int(data.get("batch_size", 0)), 0)
	_progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	_cook_time = maxf(float(data.get("cook_time", DEFAULT_COOK_TIME)), 1.0)
	_inventory = maxi(int(data.get("inventory", 0)), 0)
	_inventory_purity = clampf(float(data.get("inventory_purity", 0.0)), 0.0, 1.0)
