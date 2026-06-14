class_name StatTracker
extends RefCounted
## Pure lifetime-stats and 100%-completion model: the keyed counters GTA tracks
## (kills, headshots, missions passed, distance driven, ...) plus a few simple
## achievement thresholds derived from them.
##
## No scene access — a node feeds it gameplay events (add) and the HUD / stats
## screen reads the totals, ratios and completion, so all the maths is
## unit-tested (tests/unit/test_stat_tracker.gd). Unknown stats read as 0 and
## negative increments are ignored, so callers can trust the numbers.

## Metres per kilometre, for the distance_km readout.
const METRES_PER_KM: float = 1000.0

## Achievements as {achievement_id: {"stat": stat_id, "threshold": value}}.
## Earned the moment the keyed stat reaches the threshold; never un-earned.
const ACHIEVEMENTS: Dictionary = {
	"centurion": {"stat": "kills", "threshold": 100.0},
	"sharpshooter": {"stat": "headshots", "threshold": 50.0},
	"road_trip": {"stat": "distance_m", "threshold": 10000.0},
	"made_man": {"stat": "missions_passed", "threshold": 10.0},
	"grand_theft": {"stat": "vehicles_jacked", "threshold": 25.0},
}

## stat_id -> accumulated value. Absent keys read as 0 via get_stat.
var _stats: Dictionary = {}


func _init() -> void:
	reset()


# --- Mutators -------------------------------------------------------------


## Increment a named stat by amount (defaults to 1). Negative amounts are
## ignored, so a miscounted event can never drive a total backwards.
func add(stat_id: String, amount: float = 1.0) -> void:
	if amount < 0.0:
		return
	_stats[stat_id] = get_stat(stat_id) + amount


## Overwrite a stat outright (e.g. loading a value or a fastest-time record).
func set_stat(stat_id: String, value: float) -> void:
	_stats[stat_id] = value


func reset() -> void:
	_stats = {}


# --- Queries --------------------------------------------------------------


## Current value of a stat, or 0 if it was never touched.
func get_stat(stat_id: String) -> float:
	return float(_stats.get(stat_id, 0.0))


## A copy of every tracked stat, so the caller can't mutate our store.
func all_stats() -> Dictionary:
	return _stats.duplicate()


## Fraction of kills that were headshots, 0..1. 0 when there are no kills, so
## there is never a divide-by-zero.
func headshot_ratio() -> float:
	var kills := get_stat("kills")
	if kills <= 0.0:
		return 0.0
	return get_stat("headshots") / kills


## Total distance driven in kilometres, from the metre counter.
func distance_km() -> float:
	return get_stat("distance_m") / METRES_PER_KM


# --- Achievements ---------------------------------------------------------


## True once the achievement's stat has reached its threshold. Unknown ids
## are never achieved.
func is_achieved(achievement_id: String) -> bool:
	if not ACHIEVEMENTS.has(achievement_id):
		return false
	var rule: Dictionary = ACHIEVEMENTS[achievement_id]
	return get_stat(rule["stat"]) >= float(rule["threshold"])


## Every achievement earned so far, in table order.
func achieved_list() -> Array:
	var earned: Array = []
	for achievement_id: String in ACHIEVEMENTS:
		if is_achieved(achievement_id):
			earned.append(achievement_id)
	return earned


## Share of achievements earned as a 0..100 percentage (100 when all earned).
func completion_percent() -> float:
	var total := ACHIEVEMENTS.size()
	if total <= 0:
		return 0.0
	return 100.0 * float(achieved_list().size()) / float(total)


# --- Persistence ----------------------------------------------------------


## Snapshot the stat store for a save (mirrors save_data's plain-Dictionary
## convention). Derived stats and achievements are recomputed on restore.
func serialize() -> Dictionary:
	return {"stats": _stats.duplicate()}


## Rebuild from a serialize() snapshot. Missing or malformed data resets to a
## clean slate, so a corrupt save can't crash the stats screen.
func restore(data: Dictionary) -> void:
	reset()
	var stored: Variant = data.get("stats")
	if typeof(stored) != TYPE_DICTIONARY:
		return
	for stat_id: Variant in stored:
		_stats[str(stat_id)] = float(stored[stat_id])
