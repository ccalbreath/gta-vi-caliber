class_name Haggle
extends RefCounted
## Pure haggling / negotiation model — a back-and-forth over the price of one item, the fresh
## INTERACTION the fixed-price stalls (ShopModel / Fence / ContrabandMarket) don't have. The
## buyer opens with a LOWBALL; each time you PUSH they concede a little more toward the item's
## worth — but only up to their PATIENCE. Push past it and they're insulted: the offer slides
## back DOWN toward an insulted floor. So there's a sweet spot — squeeze them to the peak then
## take it; over-play your hand and you walk away with less.
##
## Deterministic, no nodes, no wallet coupling: accept() reports the agreed price for the
## caller to bank. Unit-tested headless (tests/unit/test_haggle.gd).

## The insulted-lowball floor and the ceiling a buyer will ever pay (never quite full worth).
const MIN_FRACTION: float = 0.1
const DEFAULT_OPENING: float = 0.5
const DEFAULT_CONCESSION: float = 0.1
const DEFAULT_MAX_FRACTION: float = 0.95
const DEFAULT_PATIENCE: int = 4
## Fraction of value lost per push BEYOND patience (they get annoyed and walk it back).
const DEFAULT_ANNOYANCE: float = 0.15

var item_value: int
var opening_fraction: float
var concession: float
var max_fraction: float
var annoyance: float
var patience: int

var _round: int = 0
var _settled: bool = false
var _final_price: int = 0


func _init(
	value: int = 0,
	opening: float = DEFAULT_OPENING,
	concession_step: float = DEFAULT_CONCESSION,
	patience_rounds: int = DEFAULT_PATIENCE,
	ceiling: float = DEFAULT_MAX_FRACTION,
	annoy: float = DEFAULT_ANNOYANCE
) -> void:
	item_value = maxi(value, 0)
	max_fraction = clampf(ceiling, MIN_FRACTION, 1.0)
	opening_fraction = clampf(opening, MIN_FRACTION, max_fraction)
	concession = maxf(concession_step, 0.0)
	patience = maxi(patience_rounds, 0)
	annoyance = maxf(annoy, 0.0)


# --- Queries -----------------------------------------------------------------


func rounds_pushed() -> int:
	return _round


func is_settled() -> bool:
	return _settled


func final_price() -> int:
	return _final_price


## The buyer's offer at the current number of pushes: climbs toward the peak at `patience`,
## then slides back down as they get annoyed. Capped at max_fraction, floored at MIN_FRACTION.
func current_offer() -> int:
	return int(round(float(item_value) * _offer_fraction()))


## What fraction of the item's value the buyer is offering right now.
func _offer_fraction() -> float:
	var frac: float
	if _round <= patience:
		frac = opening_fraction + concession * float(_round)
	else:
		# Decline from the ACTUAL (capped) peak, so over-pushing slides down immediately even
		# when a high concession already pinned the climb at max_fraction before patience.
		var peak := minf(opening_fraction + concession * float(patience), max_fraction)
		frac = peak - annoyance * float(_round - patience)
	return clampf(frac, MIN_FRACTION, max_fraction)


# --- Mutations ---------------------------------------------------------------


## Push for a better price (one haggle round). No-op once the deal is settled. Returns the
## buyer's new current offer.
func push() -> int:
	if not _settled:
		_round += 1
	return current_offer()


## Take the buyer's current offer and lock the deal. Idempotent once settled.
func accept() -> int:
	if not _settled:
		_settled = true
		_final_price = current_offer()
	return _final_price
