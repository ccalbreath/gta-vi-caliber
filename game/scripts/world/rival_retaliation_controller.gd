class_name RivalRetaliationController
extends Node
## Owns the player's ONE RivalRetaliation vendetta model and CLOSES the turf-grudge
## loop: it listens for the gang_territory node's `turf_captured` signal and provokes
## the dispossessed gang, so taking a rival's turf earns their grudge. It runs the
## model on an in-game-day clock and emits `retaliation_strike(faction, kind,
## severity)` for the scene to spawn the revenge (vandalism -> property raid -> hit
## squad). Self-wires by group ("rival_retaliation"); other systems (a hit, a heist)
## can also call provoke(). Drives the tested RivalRetaliation model
## (tests/unit/test_rival_retaliation.gd); verified in tests/rival_retaliation_probe.gd.

signal retaliation_strike(faction_id: String, kind: String, severity: float)

## Floor on the day period and cap on days advanced per frame, so a tiny
## seconds_per_day or a lag-spike delta can't run thousands of ticks in one frame.
const MIN_SECONDS_PER_DAY: float = 1.0
const MAX_DAYS_PER_FRAME: float = 10.0

## Grudge added when the player captures a rival's turf. Keep it comfortably above
## RETALIATE_AT + RETALIATION_COOLDOWN_DAYS * decay (~46) so the grudge survives the
## strike cooldown and the gang actually retaliates rather than cooling off first.
@export var turf_grudge: float = 50.0
## Real seconds per in-game day for the retaliation / grudge-decay clock (<=0 pauses).
@export var seconds_per_day: float = 60.0

var _rivalry: RivalRetaliation
var _day_accum: float = 0.0
## Weak ref to the turf source we're connected to; re-binds if it's freed/replaced.
var _territory_ref: WeakRef = null


func _ready() -> void:
	_rivalry = RivalRetaliation.new()
	add_to_group("rival_retaliation")


func _process(delta: float) -> void:
	_bind_territory()
	if seconds_per_day <= 0.0 or _rivalry == null:
		return
	var period := maxf(seconds_per_day, MIN_SECONDS_PER_DAY)
	_day_accum = minf(_day_accum + delta, period * MAX_DAYS_PER_FRAME)
	while _day_accum >= period:
		_day_accum -= period
		for strike: Dictionary in _rivalry.tick(1.0):
			retaliation_strike.emit(strike["faction_id"], strike["kind"], strike["severity"])


## Connect to the turf source whenever it appears, and RE-connect if the node we
## were bound to has been freed/replaced (works in any spawn order).
func _bind_territory() -> void:
	if _territory_ref != null and is_instance_valid(_territory_ref.get_ref()):
		return
	var territory := get_tree().get_first_node_in_group("gang_territory")
	if territory != null and territory.has_signal("turf_captured"):
		if not territory.is_connected("turf_captured", _on_turf_captured):
			territory.connect("turf_captured", _on_turf_captured)
		_territory_ref = weakref(territory)


func _on_turf_captured(_district_id: String, from_owner: String) -> void:
	provoke(from_owner, turf_grudge)


## Raise a faction's grudge (turf taken, a hit, a heist hit). Returns the new grudge,
## or -1.0 for an unknown faction.
func provoke(faction_id: String, amount: float) -> float:
	return _rivalry.provoke(faction_id, amount) if _rivalry != null else -1.0


## Cool a faction down (a truce / pay-off). Returns the new grudge.
func pacify(faction_id: String, amount: float) -> float:
	return _rivalry.pacify(faction_id, amount) if _rivalry != null else -1.0


## Current grudge of a faction (0 if unknown / not ready).
func grudge_of(faction_id: String) -> float:
	return _rivalry.grudge_of(faction_id) if _rivalry != null else 0.0


## Whether a faction is actively seeking revenge.
func is_seeking_revenge(faction_id: String) -> bool:
	return _rivalry != null and _rivalry.is_seeking_revenge(faction_id)
