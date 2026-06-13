class_name PlayerBountyController
extends Node
## Owns the player's ONE PlayerBounty and CLOSES the grudge->bounty seam: it listens
## for RivalRetaliation strikes and, scaled by the strike's severity, has the
## aggrieved gang put a PRICE ON THE PLAYER'S HEAD. As strikes escalate the bounty
## climbs through its tiers, drawing more and tougher NPC hunters (hunter_count /
## threat_level); `hunters_changed` tells the scene to spawn/despawn them. The bounty
## fades over in-game days; clear it by paying a fixer (pay), a private truce
## (appease), or laying low. Self-wires by group ("player_bounty"); drives the
## tested PlayerBounty model. Verified in tests/player_bounty_probe.gd.

signal hunters_changed(count: int, threat: float)

## Floor on the day period + cap on days advanced per frame (a tiny seconds_per_day
## or a lag spike can't run thousands of decay ticks in one frame).
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

## Bounty cash a full-severity (1.0) retaliation strike puts on the player's head
## (capped per-gang by PlayerBounty.MAX_PER_PLACER).
@export_range(1.0, 50000.0, 1.0) var bounty_per_severity: float = 12000.0
## Real seconds per in-game day for the bounty-decay clock (<=0 pauses).
@export var seconds_per_day: float = 90.0

var _bounty: PlayerBounty
var _day_accum: float = 0.0
## Weak ref to the strike source we're connected to; re-binds if it's freed/replaced.
var _rival_ref: WeakRef = null
var _last_hunters: int = 0


func _ready() -> void:
	_bounty = PlayerBounty.new()
	add_to_group("player_bounty")


func _process(delta: float) -> void:
	_bind_rival()
	if seconds_per_day <= 0.0 or _bounty == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		_bounty.decay(1.0)
	_emit_if_hunters_changed()


## Connect to the strike source whenever it appears, re-connecting if the node we
## bound to is freed/replaced (works in any spawn order).
func _bind_rival() -> void:
	if _rival_ref != null and is_instance_valid(_rival_ref.get_ref()):
		return
	var rival := get_tree().get_first_node_in_group("rival_retaliation")
	if rival != null and rival.has_signal("retaliation_strike"):
		if not rival.is_connected("retaliation_strike", _on_strike):
			rival.connect("retaliation_strike", _on_strike)
		_rival_ref = weakref(rival)


func _on_strike(faction_id: String, _kind: String, severity: float) -> void:
	if _bounty != null:
		_bounty.place_bounty(faction_id, severity * bounty_per_severity)
		_emit_if_hunters_changed()


## Announce when the number of hunters on the player changes (spawn / despawn).
func _emit_if_hunters_changed() -> void:
	var count := hunter_count()
	if count != _last_hunters:
		_last_hunters = count
		hunters_changed.emit(count, threat_level())


# --- Passthroughs for HUD / spawning / resolution -------------------------


## Total bounty on the player's head across every gang.
func total_bounty() -> int:
	return _bounty.total_bounty() if _bounty != null else 0


## How many hunters should be pursuing, by bounty tier.
func hunter_count() -> int:
	return _bounty.hunter_count() if _bounty != null else 0


## 0..1 overall danger of the bounty (for scaling hunter gear / aggression).
func threat_level() -> float:
	return _bounty.threat_level() if _bounty != null else 0.0


## Named bounty tier ("none" when clear).
func tier() -> String:
	return _bounty.tier() if _bounty != null else "none"


## Pay the whole bounty off at a fixer against a wallet balance.
func pay(balance: int) -> Dictionary:
	if _bounty == null:
		return {"success": false}
	var result := _bounty.pay(balance)
	_emit_if_hunters_changed()  # clearing the bounty stands the hunters down
	return result


## A private truce with one gang (reduce just their share).
func appease(faction_id: String, amount: float) -> float:
	if _bounty == null:
		return 0.0
	var left := _bounty.appease(faction_id, amount)
	_emit_if_hunters_changed()
	return left


## A hunter kills the player and collects: returns the whole bounty as their payout,
## clears it, and stands the hunters down.
func claim() -> int:
	if _bounty == null:
		return 0
	var payout := _bounty.claim()
	_emit_if_hunters_changed()
	return payout
