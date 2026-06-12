class_name PlayerProgression
extends RefCounted
## Pure respect/XP progression model: levels on a rising curve plus per-level
## unlocks earned through play.
##
## No scene access — a node (HUD, mission reward handler) owns one and feeds it
## respect payouts, so the levelling curve and unlock gates are unit-tested
## (tests/unit/test_player_progression.gd).
##
## Curve: each level costs `XP_PER_LEVEL_STEP * level` to *leave*, i.e. going
## from level L to L+1 costs 100 * L. That makes the cumulative XP to first
## reach level L a triangular number: 100 * (L-1) * L / 2. A simple, clearly
## rising curve so a big payout can jump several levels with an exact remainder.

const START_LEVEL: int = 1
const MAX_LEVEL: int = 50
## Per-level slope: leaving level `level` costs XP_PER_LEVEL_STEP * level.
const XP_PER_LEVEL_STEP: int = 100

## Features unlocked the moment the player first reaches the keyed level.
const UNLOCK_TABLE: Dictionary = {
	2: ["pistol_slot"],
	5: ["sports_car", "ammo_discount"],
	10: ["smg_slot", "garage_slot"],
	20: ["helicopter", "armor_discount"],
	35: ["rifle_slot"],
	50: ["heist_crew"],
}

var _level: int = START_LEVEL
## Respect accumulated *within* the current level (resets to leftover on level-up).
var _xp_into_level: int = 0
## Lifetime respect ever earned, for stat screens.
var _total_xp: int = 0


func _init() -> void:
	reset()


# --- Mutators -------------------------------------------------------------


## Earn respect. Rolls over into as many new levels as the payout funds (a big
## bonus can jump several at once), capped at MAX_LEVEL where surplus is dropped.
## Negative amounts are ignored.
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	_total_xp += amount
	if _level >= MAX_LEVEL:
		_xp_into_level = 0
		return
	_xp_into_level += amount
	while _level < MAX_LEVEL and _xp_into_level >= xp_for_next():
		_xp_into_level -= xp_for_next()
		_level += 1
	if _level >= MAX_LEVEL:
		_xp_into_level = 0


func reset() -> void:
	_level = START_LEVEL
	_xp_into_level = 0
	_total_xp = 0


# --- Queries --------------------------------------------------------------


func level() -> int:
	return _level


## Alias for respect-within-level; respect and xp are the same currency here.
func xp() -> int:
	return _xp_into_level


func xp_into_level() -> int:
	return _xp_into_level


func total_xp() -> int:
	return _total_xp


## Cost to leave the current level (reach the next). 0 at max level.
func xp_for_next() -> int:
	if _level >= MAX_LEVEL:
		return 0
	return XP_PER_LEVEL_STEP * _level


## Progress through the current level in 0..1. 1.0 at max level.
func level_progress() -> float:
	if _level >= MAX_LEVEL:
		return 1.0
	var need := xp_for_next()
	if need <= 0:
		return 1.0
	return clampf(float(_xp_into_level) / float(need), 0.0, 1.0)


func is_max_level() -> bool:
	return _level >= MAX_LEVEL


# --- Curve & unlocks ------------------------------------------------------


## Cumulative respect needed to first reach `target_level` from a fresh start:
## the triangular sum of per-level costs. reach(1) == 0.
static func xp_to_reach(target_level: int) -> int:
	var clamped := clampi(target_level, START_LEVEL, MAX_LEVEL)
	var levels_climbed := clamped - START_LEVEL
	# Sum of 100*1 + 100*2 + ... + 100*levels_climbed (costs of levels 1..n).
	return XP_PER_LEVEL_STEP * levels_climbed * (levels_climbed + 1) / 2


## Features that unlock exactly at `target_level` (empty if none keyed there).
static func unlocks_at(target_level: int) -> Array:
	return UNLOCK_TABLE.get(target_level, []).duplicate()


## True if `feature_id` is unlocked at the current level (any gate <= level).
func is_unlocked(feature_id: String) -> bool:
	for gate_level: int in UNLOCK_TABLE:
		if gate_level <= _level and UNLOCK_TABLE[gate_level].has(feature_id):
			return true
	return false
