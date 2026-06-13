class_name PlayerBounty
extends RefCounted
## Pure bounty-on-the-player's-head model — a placed cash reward that draws NPC bounty
## hunters, distinct from WantedSystem (live police heat) and CrimeNotoriety
## (reputation). A rival gang or wronged NPC PLACES a bounty (scaled by how badly you
## crossed them); the total across all placers sets a tier that decides how many / how
## tough the hunters who come for you are. You clear it three ways: lay low (it decays
## over in-game days), pay it off at a fixer (pay()), or get killed — a hunter claims
## it (claim()).
##
## No scene access: a world/AI controller owns one, calls place_bounty(faction, amount)
## when the player wrongs someone (e.g. off RivalRetaliation / FactionStanding /
## CrimeNotoriety), reads hunter_count()/threat_level() to spawn + scale pursuers, and
## resolves it via pay() (wallet by caller) / claim() (on player death) / decay() each
## day. Unit-tested headless (tests/unit/test_player_bounty.gd).
##
## Placer rows aren't pre-registered — any id can place a bounty at runtime; amounts
## are clamped per placer and non-positive amounts ignored.

const MIN_BOUNTY: float = 0.0
## Max a single placer can stack on your head, and the overall cap across all placers.
const MAX_PER_PLACER: float = 50000.0
const MAX_TOTAL_BOUNTY: int = 250000
## Total-bounty tier thresholds (sum across all placers).
const WANTED_AT: float = 1.0
const HUNTED_AT: float = 5000.0
const MARKED_AT: float = 20000.0
const LEGENDARY_AT: float = 40000.0
## Hunters dispatched at each tier.
const MAX_HUNTERS: int = 5
## Bounty that fades per in-game day while laying low.
const DECAY_PER_DAY: float = 500.0
## Total bounty at which threat_level() saturates to 1.0.
const THREAT_SATURATION: float = 50000.0

## placer_id -> bounty amount they've placed.
var _placed: Dictionary = {}

# --- Placing / queries ----------------------------------------------------


## Add `amount` to the bounty a placer has on your head (non-positive ignored), clamped
## per placer. Returns the placer's new bounty, unknown-safe.
func place_bounty(placer_id: String, amount: float) -> float:
	if placer_id.is_empty() or amount <= 0.0:
		return bounty_from(placer_id)
	_placed[placer_id] = clampf(bounty_from(placer_id) + amount, MIN_BOUNTY, MAX_PER_PLACER)
	return _placed[placer_id]


## Bounty a single placer has on you (0 if none).
func bounty_from(placer_id: String) -> float:
	return _placed[placer_id] if _placed.has(placer_id) else 0.0


## Placer ids with an active bounty, sorted.
func placers() -> Array:
	var out: Array = _placed.keys()
	out.sort()
	return out


## Combined bounty across every placer (truncated to whole dollars so a sub-$1
## remainder never reads as active, and capped at MAX_TOTAL_BOUNTY).
func total_bounty() -> int:
	var sum: float = 0.0
	for id: String in _placed:
		sum += float(_placed[id])
	return clampi(int(sum), 0, MAX_TOTAL_BOUNTY)


func is_active() -> bool:
	return total_bounty() > 0


## Named tier for the current total bounty ("none" when clear).
func tier() -> String:
	var total: float = float(total_bounty())
	if total >= LEGENDARY_AT:
		return "legendary"
	if total >= MARKED_AT:
		return "marked"
	if total >= HUNTED_AT:
		return "hunted"
	if total >= WANTED_AT:
		return "wanted"
	return "none"


## How many bounty hunters should be pursuing, by tier.
func hunter_count() -> int:
	match tier():
		"legendary":
			return MAX_HUNTERS
		"marked":
			return 3
		"hunted":
			return 2
		"wanted":
			return 1
	return 0


## 0..1 overall danger from the bounty (for scaling hunter gear / aggression).
func threat_level() -> float:
	return clampf(float(total_bounty()) / THREAT_SATURATION, 0.0, 1.0)


# --- Resolution -----------------------------------------------------------


## A hunter kills you and collects: returns the whole bounty as their payout and clears
## it (you respawn clean). 0 if there was no bounty.
func claim() -> int:
	var payout: int = total_bounty()
	_placed = {}
	return payout


## Pay your own bounty off at a fixer against a wallet balance. Returns
## {success, cost, new_balance, reason}. Fails for nothing-outstanding / insufficient
## funds (state unchanged).
func pay(balance: int) -> Dictionary:
	var owed: int = total_bounty()
	if owed <= 0:
		return _fail(balance, "no bounty to pay")
	if balance < owed:
		return _fail(balance, "insufficient funds: need %d, have %d" % [owed, balance])
	_placed = {}
	return {"success": true, "cost": owed, "new_balance": balance - owed, "reason": ""}


## Reduce a single placer's bounty (a private truce / pay-off). Non-positive ignored.
func appease(placer_id: String, amount: float) -> float:
	if not _placed.has(placer_id) or amount <= 0.0:
		return bounty_from(placer_id)
	var left: float = maxf(float(_placed[placer_id]) - amount, MIN_BOUNTY)
	if left <= 0.0:
		_placed.erase(placer_id)
		return 0.0
	_placed[placer_id] = left
	return left


# --- Time -----------------------------------------------------------------


## Lay low: every placer's bounty fades by DECAY_PER_DAY * delta_days; a bounty that
## reaches 0 is dropped. Non-positive spans are ignored.
func decay(delta_days: float) -> void:
	if delta_days <= 0.0:
		return
	var drop: float = DECAY_PER_DAY * delta_days
	for id: String in _placed.keys():
		var left: float = maxf(float(_placed[id]) - drop, MIN_BOUNTY)
		if left <= 0.0:
			_placed.erase(id)
		else:
			_placed[id] = left


# --- Persistence ----------------------------------------------------------


func serialize() -> Dictionary:
	var placed: Dictionary = {}
	for id: String in placers():
		placed[id] = _placed[id]
	return {"placed": placed}


## Restore placed bounties; values clamped per placer, non-numeric dropped.
func restore(data: Dictionary) -> void:
	_placed = {}
	var stored: Variant = data.get("placed")
	if not (stored is Dictionary):
		return
	var placed: Dictionary = stored
	for key: Variant in placed:
		if placed[key] is float or placed[key] is int:
			var amount: float = clampf(float(placed[key]), MIN_BOUNTY, MAX_PER_PLACER)
			if amount > 0.0:
				_placed[str(key)] = amount


# --- Internal -------------------------------------------------------------


func _fail(balance: int, reason: String) -> Dictionary:
	return {"success": false, "cost": 0, "new_balance": balance, "reason": reason}
