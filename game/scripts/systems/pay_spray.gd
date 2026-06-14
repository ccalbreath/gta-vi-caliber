class_name PaySpray
extends RefCounted
## Pure PAY-N-SPRAY / hideout instant wanted-loss model — the iconic GTA respray.
##
## Duck into a spray shop or safehouse and, IF no cop saw you enter, the wanted
## level clears the moment the door shuts. This is the INSTANT-CLEAR path and is
## deliberately distinct from WantedEvasion's slow "go cold" countdown: there you
## have to break sight and wait it out; here you pay and the heat is gone.
##
## No scene access. Static eligibility checks (can_enter / is_seen_entering /
## cost_for) plus a tiny stateful respray timer (the seconds spent inside with the
## door shut), so the whole mechanic is unit-tested (tests/unit/test_pay_spray.gd).
## A node feeds it the player/shop/police positions, the wallet balance, and delta.

## Default per-star respray surcharge when a caller doesn't supply one.
const DEFAULT_PER_STAR: int = 100

var respray_duration: float
var _running: bool = false
var _time: float = 0.0


func _init(respray_duration_seconds: float = 3.0) -> void:
	# Guard against zero/negative so progress() never divides by zero and the
	# respray always takes a finite, completable amount of time.
	respray_duration = maxf(respray_duration_seconds, 0.001)


## True when the player is at the shop entrance (within entry_radius). A negative
## radius is treated as zero, so a bad value can never wave the player in.
static func can_enter(player_pos: Vector3, shop_pos: Vector3, entry_radius: float) -> bool:
	var reach := maxf(entry_radius, 0.0)
	return player_pos.distance_to(shop_pos) <= reach


## Respray price for the current heat: higher stars cost more. 0 stars -> 0 (there
## is nothing to lose, so there is nothing to pay). Stars are clamped to 0..5 and
## base_cost/per_star floored at 0 so the price is never negative.
static func cost_for(stars: int, base_cost: int, per_star: int = DEFAULT_PER_STAR) -> int:
	var heat := clampi(stars, 0, WantedSystem.MAX_STARS)
	if heat <= 0:
		return 0
	return maxi(base_cost, 0) + maxi(per_star, 0) * heat


## True if any cop is close enough to the shop entrance to watch you duck in
## (within sight_radius). If so the respray WON'T clear — you've been traced.
## Malformed entries (missing/invalid pos) are ignored, never treated as a sighting.
static func is_seen_entering(shop_pos: Vector3, police: Array, sight_radius: float) -> bool:
	var sight := maxf(sight_radius, 0.0)
	for cop in police:
		if not (cop is Dictionary) or not cop.has("pos"):
			continue
		var pos: Variant = cop["pos"]
		if not (pos is Vector3):
			continue
		if pos.distance_to(shop_pos) <= sight:
			return true
	return false


## Begin the respray timer from scratch (the door just shut behind you).
func begin() -> void:
	_running = true
	_time = 0.0


## Advance the respray. No-op before begin(), after completion, or for a
## non-positive delta, so a stray frame can't push a stale timer forward.
func tick(delta: float) -> void:
	if not _running:
		return
	if _time >= respray_duration:
		return
	_time = minf(_time + maxf(delta, 0.0), respray_duration)


## 0.0 at begin, ramping to 1.0 when the respray finishes. 0.0 before begin().
func progress() -> float:
	if not _running:
		return 0.0
	return clampf(_time / respray_duration, 0.0, 1.0)


## True once the car has been resprayed long enough — the wanted level may clear.
func is_complete() -> bool:
	return _running and _time >= respray_duration


## Abort an in-progress respray (you bailed before the job finished).
func cancel() -> void:
	_running = false
	_time = 0.0


## Back to the idle/pre-begin state.
func reset() -> void:
	_running = false
	_time = 0.0


## Resolve a respray attempt against the wallet. Pure: the caller applies
## new_balance (PlayerStats.spend_money) and, on allowed, clears the wanted level.
## Fails when: 0 stars (nothing to lose), a cop saw you enter (traced), or the
## balance can't cover the cost. Returns {allowed, cost, new_balance, reason}.
func resolve(
	stars: int, balance: int, seen: bool, base_cost: int, per_star: int = DEFAULT_PER_STAR
) -> Dictionary:
	if stars <= 0:
		return _deny(balance, "not wanted: nothing to respray")
	if seen:
		return _deny(balance, "seen entering: police traced you")
	var cost := PaySpray.cost_for(stars, base_cost, per_star)
	if balance < cost:
		return _deny(balance, "insufficient funds: need %d, have %d" % [cost, balance])
	return {
		"allowed": true,
		"cost": cost,
		"new_balance": balance - cost,
		"reason": "",
	}


func _deny(balance: int, reason: String) -> Dictionary:
	return {"allowed": false, "cost": 0, "new_balance": balance, "reason": reason}
