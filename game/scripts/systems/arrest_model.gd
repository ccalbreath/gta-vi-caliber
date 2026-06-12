class_name ArrestModel
extends RefCounted
## Pure "Busted" resolution — the arrest counterpart to a Wasted (death). When the
## police corner the player (hold them within catch range while wanted) for a
## short grapple window, the bust lands: the player respawns stripped of a slice
## of cash and all heat. Today only the Wasted path exists (police deal melee
## damage); this closes the other half of the GTA fail loop.
##
## Static, scene-free, RNG-free — unit-tested headless
## (tests/unit/test_arrest_model.gd). A node tracks the grapple timer per frame
## (PlayerStats.spend_money for the fee, WantedTracker.clear for the heat,
## PlayerHealth-style respawn), feeding these helpers.

## Seconds the player must be cornered before the cuffs go on.
const DEFAULT_GRAPPLE_TIME := 1.5
## Fraction of the wallet forfeited on a bust.
const DEFAULT_CASH_PENALTY := 0.10


## Is an officer cornering the player this tick — wanted, and within catch range.
static func cornered(stars: int, distance: float, catch_distance: float) -> bool:
	return stars > 0 and distance <= catch_distance


## Advance the grapple timer: it counts up while the player is cornered and bleeds
## back off (never below zero) the instant they break free, so a clean getaway
## resets the bust.
static func tick_grapple(time_held: float, is_cornered: bool, dt: float) -> float:
	return maxf(time_held + dt, 0.0) if is_cornered else maxf(time_held - dt, 0.0)


## A bust lands once the player has been cornered continuously for grapple_time.
static func is_busted(time_held: float, grapple_time: float) -> bool:
	return grapple_time > 0.0 and time_held >= grapple_time


## Cash kept after a bust: the wallet minus the penalty fraction, floored at 0.
static func cash_after_bust(wallet: int, penalty_fraction: float) -> int:
	var kept := float(wallet) * (1.0 - clampf(penalty_fraction, 0.0, 1.0))
	return maxi(floori(kept), 0)


## The cash a bust takes (wallet minus what's kept), never negative.
static func bust_fee(wallet: int, penalty_fraction: float) -> int:
	return maxi(wallet - cash_after_bust(wallet, penalty_fraction), 0)
