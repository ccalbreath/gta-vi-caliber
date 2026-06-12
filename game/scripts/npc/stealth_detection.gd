class_name StealthDetection
extends RefCounted
## Pure stealth-detection awareness meter — the "eye" that fills up before an NPC
## or cop actually spots the player. Sits one layer above CrimeWitness: that does
## the instantaneous can-I-see-it FOV check, this is the TIME-BASED meter built on
## top, so a target glimpsed for a frame doesn't flip straight to ALERTED.
##
## A stateful instance (one per watcher). Awareness is 0..1 and walks through
## UNAWARE -> SUSPICIOUS -> ALERTED as the watcher keeps eyes on the player, and
## decays back down when sight is lost. ALERTED is sticky once reached: a full
## meter means "spotted", and a momentary flicker of sight doesn't un-spot the
## player — only reset() clears it.
##
## No nodes, statically typed, defensive (negative delta / out-of-range inputs are
## clamped, not trusted). Unit-tested headless (tests/unit/test_stealth_detection.gd).

enum State { UNAWARE, SUSPICIOUS, ALERTED }

var _fill_rate: float
var _decay_rate: float
var _suspicious_threshold: float
var _awareness: float = 0.0
var _alerted: bool = false


## `fill_rate` is awareness/second gained at full visibility while seen;
## `decay_rate` is awareness/second lost while not seen. `suspicious_threshold`
## (0..1) is where UNAWARE becomes SUSPICIOUS. Rates are floored at zero and the
## threshold clamped into (0,1) so a degenerate config can't misbehave.
func _init(fill_rate: float, decay_rate: float, suspicious_threshold: float = 0.4) -> void:
	_fill_rate = maxf(fill_rate, 0.0)
	_decay_rate = maxf(decay_rate, 0.0)
	_suspicious_threshold = clampf(suspicious_threshold, 0.0001, 0.9999)


## Advance one frame. `can_see_player` gates everything — when false the meter
## decays. `visibility` (0..1) scales the fill speed: a close, lit, moving target
## fills fast; a distant, dark, crouched one barely at all (visibility 0 can't
## fill even while can_see is true — you see a shape but can't make it out).
## Negative delta is ignored so time never runs backwards. Once ALERTED the meter
## stays pinned and sticky; only reset() releases it.
func update(can_see_player: bool, visibility: float, delta: float) -> void:
	if delta <= 0.0:
		return
	if _alerted:
		_awareness = 1.0
		return
	if can_see_player:
		var vis := clampf(visibility, 0.0, 1.0)
		_awareness = clampf(_awareness + _fill_rate * vis * delta, 0.0, 1.0)
	else:
		_awareness = maxf(_awareness - _decay_rate * delta, 0.0)
	if _awareness >= 1.0:
		_alerted = true


## Current awareness, 0..1.
func awareness() -> float:
	return _awareness


## Current discrete state (see enum State).
func state() -> int:
	if _alerted:
		return State.ALERTED
	if _awareness >= _suspicious_threshold:
		return State.SUSPICIOUS
	return State.UNAWARE


func is_alerted() -> bool:
	return _alerted


func is_suspicious() -> bool:
	return state() == State.SUSPICIOUS


## Pure visibility helper (0..1) the caller can feed into update(). Visibility
## falls off linearly with distance/`max_range` (out of range -> 0), is cut while
## the target is crouched, and raised while it is moving. The result is clamped
## 0..1 so any mix of factors stays a valid visibility.
func detection_speed(
	distance: float, max_range: float, target_crouched: bool, target_moving: bool
) -> float:
	if max_range <= 0.0 or distance >= max_range:
		return 0.0
	var falloff := 1.0 - clampf(distance, 0.0, max_range) / max_range
	if target_crouched:
		falloff *= 0.45
	if target_moving:
		falloff *= 1.4
	return clampf(falloff, 0.0, 1.0)


## Wipe the meter back to UNAWARE and clear the sticky ALERTED latch.
func reset() -> void:
	_awareness = 0.0
	_alerted = false
