class_name MissionModifier
extends RefCounted
## Pure per-mission modifier model — the optional-challenge layer that makes a mission
## or heist replayable: a roster of modifiers (a time limit, no-damage run, extra
## enemies, stay-undetected, reverse route) that each make a mission HARDER and, in
## exchange, multiply the PAYOUT. A mission instance activates a few of them (rolled
## deterministically from a seed, or chosen by the player), and the model reports the
## combined difficulty and the payout multiplier the reward calculation applies.
##
## No scene access: a mission controller owns one, calls roll(seed, n) (or
## activate(id)) when a mission starts, reads combined_difficulty() to scale enemy
## counts / timers and apply_to_payout(base) to size the cash reward (which the caller
## pays out, like MissionReward), and is_active(id) to enable the matching rule (a
## countdown, a damage-fail check). Composes with HeistCrew (a higher combined
## difficulty lowers crew success odds). Unit-tested headless
## (tests/unit/test_mission_modifier.gd).
##
## Modifier row: {id, name, difficulty, payout_mult}. Rows with a missing/empty id, a
## payout_mult < 1.0 (a modifier never pays LESS), or a duplicate id are dropped.

## id -> {name: String, difficulty: float, payout_mult: float}.
var _catalogue: Dictionary = {}
## Set of currently-active modifier ids for this mission (id -> true).
var _active: Dictionary = {}


func _init(modifiers: Array = []) -> void:
	var source: Array = modifiers if not modifiers.is_empty() else default_modifiers()
	for entry: Variant in source:
		_register(entry)


## Built-in modifier roster: each adds difficulty and a payout bonus.
static func default_modifiers() -> Array:
	return [
		{"id": "time_limit", "name": "Beat the Clock", "difficulty": 0.3, "payout_mult": 1.25},
		{"id": "no_damage", "name": "Untouchable", "difficulty": 0.6, "payout_mult": 1.5},
		{"id": "extra_enemies", "name": "Heavy Resistance", "difficulty": 0.5, "payout_mult": 1.4},
		{"id": "stay_undetected", "name": "Ghost", "difficulty": 0.7, "payout_mult": 1.6},
		{"id": "reverse_route", "name": "Backwards", "difficulty": 0.2, "payout_mult": 1.15},
	]


# --- Catalogue queries ----------------------------------------------------


func modifier_count() -> int:
	return _catalogue.size()


func has_modifier(id: String) -> bool:
	return _catalogue.has(id)


## Catalogue ids, sorted for deterministic rolls / tests.
func ids() -> Array:
	var out: Array = _catalogue.keys()
	out.sort()
	return out


## Difficulty a modifier adds (0.0 for unknown).
func difficulty_of(id: String) -> float:
	return _catalogue[id]["difficulty"] if _catalogue.has(id) else 0.0


## Payout multiplier a modifier contributes (1.0 for unknown — no effect).
func payout_mult_of(id: String) -> float:
	return _catalogue[id]["payout_mult"] if _catalogue.has(id) else 1.0


# --- Active set -----------------------------------------------------------


## Enable a modifier for the current mission. False for an unknown / already-active id.
func activate(id: String) -> bool:
	if not _catalogue.has(id) or _active.has(id):
		return false
	_active[id] = true
	return true


## Disable a modifier. False if it wasn't active.
func deactivate(id: String) -> bool:
	return _active.erase(id)


func is_active(id: String) -> bool:
	return _active.has(id)


## Active modifier ids, sorted.
func active_ids() -> Array:
	var out: Array = _active.keys()
	out.sort()
	return out


func active_count() -> int:
	return _active.size()


func clear_active() -> void:
	_active = {}


## Deterministically pick `count` distinct modifiers for a mission from `seed` (so the
## same seed always yields the same set — replayable / testable). Replaces the active
## set. Returns the new active ids.
func roll(seed: int, count: int) -> Array:
	_active = {}
	var pool: Array = ids()
	if pool.is_empty() or count <= 0:
		return active_ids()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var shuffled: Array = pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var pick: int = mini(count, shuffled.size())
	for k in pick:
		_active[shuffled[k]] = true
	return active_ids()


# --- Combined effect ------------------------------------------------------


## Summed difficulty of every active modifier (0.0 when none active).
func combined_difficulty() -> float:
	var total: float = 0.0
	for id: String in _active:
		total += float(_catalogue[id]["difficulty"])
	return total


## Product of every active modifier's payout multiplier (1.0 when none active) — more
## modifiers stack into a bigger reward.
func combined_payout_mult() -> float:
	var mult: float = 1.0
	for id: String in _active:
		mult *= float(_catalogue[id]["payout_mult"])
	return mult


## Scale a base reward by the active modifiers (floored to whole money).
func apply_to_payout(base: int) -> int:
	return int(floor(float(base) * combined_payout_mult()))


# --- Persistence ----------------------------------------------------------


func serialize() -> Dictionary:
	return {"active": active_ids()}


## Restore the active set from a serialize() snapshot. Unknown ids are dropped;
## malformed input clears the active set.
func restore(data: Dictionary) -> void:
	_active = {}
	var stored: Variant = data.get("active")
	if not (stored is Array):
		return
	for entry: Variant in stored:
		var id: String = str(entry)
		if _catalogue.has(id):
			_active[id] = true


# --- Internal -------------------------------------------------------------


## Validate and store one modifier row; drops malformed (no/empty id, payout_mult < 1)
## and duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	var payout_mult: float = float(row.get("payout_mult", 1.0))
	if id.is_empty() or _catalogue.has(id) or payout_mult < 1.0:
		return
	_catalogue[id] = {
		"name": str(row.get("name", id)),
		"difficulty": maxf(float(row.get("difficulty", 0.0)), 0.0),
		"payout_mult": payout_mult,
	}
