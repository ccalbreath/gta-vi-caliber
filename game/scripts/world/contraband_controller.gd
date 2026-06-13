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
## total_carried() is the hook a future bust-risk / wanted feed reads — carrying
## more contraband should raise the odds of a police stop (ContrabandMarket.bust_risk).

var _market: ContrabandMarket


func _ready() -> void:
	_market = ContrabandMarket.new()
	add_to_group("contraband")


## The shared market a stall trades into (district prices + carried inventory).
func market() -> ContrabandMarket:
	return _market


## Units of a good the player is currently carrying (0 if none / not ready).
func carrying(good: String) -> int:
	return _market.carried(good) if _market != null else 0


## Total units of all contraband on the player — feed a bust-risk / heat hook.
func total_carried() -> int:
	return _market.total_carried() if _market != null else 0
