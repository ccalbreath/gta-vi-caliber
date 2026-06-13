class_name ContrabandController
extends Node
## Owns the player's ONE black-market state — the ContrabandMarket model holding
## district prices AND the contraband currently on the player. Self-wires by group
## ("contraband") so every BlackMarketStall buys/sells into the SAME inventory: a
## parcel bought in one district can be carried to another and sold there. Drives
## the tested ContrabandMarket model (tests/unit/test_contraband_market.gd); the
## only scene contact is the group registration, so it verifies in a mock tree
## (tests/black_market_probe.gd).
##
## CLOSES the bust-risk seam: while the player carries contraband, suspicion
## accrues at ContrabandMarket.bust_risk() (higher the more you carry); when it
## crosses the threshold the player gets BUSTED — heat is added to the `wanted`
## tracker (report_crime) and exposure resets. Ditch or sell the stash and the risk
## clears. So a mule loaded with product draws police far faster than a clean walk.

## Fired when carried contraband draws a police bust (heat already reported).
signal busted(carried_total: int)

## Baseline police suspicion even with a light load (0..1).
@export_range(0.0, 1.0) var base_bust_risk: float = 0.05
## Seconds to a bust while carrying at FULL suspicion (risk 1.0); scales inversely
## with the load, so a heavy mule is caught much sooner. <=0 disables the risk.
@export_range(0.0, 600.0) var seconds_per_bust: float = 45.0

var _market: ContrabandMarket
var _exposure: float = 0.0


func _ready() -> void:
	_market = ContrabandMarket.new()
	add_to_group("contraband")


func _process(delta: float) -> void:
	if _market == null or seconds_per_bust <= 0.0:
		return
	var carried := _market.total_carried()
	if carried <= 0:
		_exposure = 0.0  # nothing on you -> nothing to bust you for
		return
	# Carry the surplus past the threshold into the next cycle (no lost time), but cap
	# the meter so one huge delta can't queue an unbounded run of busts.
	var gain := _market.bust_risk(carried, base_bust_risk) * (delta / seconds_per_bust)
	_exposure = minf(_exposure + gain, 2.0)
	if _exposure >= 1.0:
		_exposure -= 1.0  # one bust per frame; remainder rolls into the next
		_trigger_bust(carried)


## Report a contraband bust to the live wanted tracker and announce it.
func _trigger_bust(carried: int) -> void:
	var wanted := get_tree().get_first_node_in_group("wanted")
	if wanted != null and wanted.has_method("report_crime"):
		wanted.report_crime(false)
	busted.emit(carried)


## 0..1 progress toward the next contraband bust, for a HUD meter.
func bust_exposure() -> float:
	return clampf(_exposure, 0.0, 1.0)


## The shared market a stall trades into (district prices + carried inventory).
func market() -> ContrabandMarket:
	return _market


## Units of a good the player is currently carrying (0 if none / not ready).
func carrying(good: String) -> int:
	return _market.carried(good) if _market != null else 0


## Total units of all contraband on the player — feed a bust-risk / heat hook.
func total_carried() -> int:
	return _market.total_carried() if _market != null else 0
