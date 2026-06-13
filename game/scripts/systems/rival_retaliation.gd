class_name RivalRetaliation
extends RefCounted
## Pure gang-vendetta model — the grudge/revenge state machine none of the existing
## faction systems fills. When the player takes a rival gang's turf or hits them, that
## faction's GRUDGE rises; a grudge above RETALIATE_AT makes them seek revenge, and on
## a cooldown they strike back — vandalising the player's property, raiding it, or
## sending a hit squad, escalating with the grudge. Grudges fade over in-game days, and
## the player can pacify a faction (a truce / pay-off) to cool one down.
##
## No scene access: a world/AI controller owns one, calls provoke(faction, amount) when
## the player wrongs a gang (turf taken via GangTerritory, a hit, a heist), advances it
## with tick(delta_days), and spawns the returned retaliation events (ambushers / a
## property attack) at the player's holdings. Faction ids line up with GangTerritory /
## FactionStanding. Unit-tested headless (tests/unit/test_rival_retaliation.gd).
##
## Faction row: {id, decay_per_day?}. Rows with a missing/empty id, or a duplicate id,
## are dropped; decay clamped >= 0.

const MIN_GRUDGE: float = 0.0
const MAX_GRUDGE: float = 100.0
## Grudge at/above which a faction actively seeks revenge.
const RETALIATE_AT: float = 40.0
## Grudge thresholds escalating the kind of strike.
const RAID_AT: float = 60.0
const HIT_SQUAD_AT: float = 80.0
## In-game days between a hostile faction's strikes.
const RETALIATION_COOLDOWN_DAYS: float = 2.0
## Default grudge fade per day.
const DEFAULT_DECAY_PER_DAY: float = 3.0

## id -> {decay_per_day: float, grudge: float, cooldown: float}.
var _factions: Dictionary = {}


func _init(factions: Array = []) -> void:
	var source: Array = factions if not factions.is_empty() else default_factions()
	for entry: Variant in source:
		_register(entry)


## Built-in rival factions, ids aligned with GangTerritory / FactionStanding.
static func default_factions() -> Array:
	return [
		{"id": "vice_kings"},
		{"id": "marina_cartel"},
		{"id": "los_santos_set"},
	]


# --- Queries --------------------------------------------------------------


func faction_count() -> int:
	return _factions.size()


func has_faction(id: String) -> bool:
	return _factions.has(id)


func ids() -> Array:
	var out: Array = _factions.keys()
	out.sort()
	return out


## Current grudge in [0, MAX_GRUDGE] (0 for an unknown faction).
func grudge_of(id: String) -> float:
	return _factions[id]["grudge"] if _factions.has(id) else 0.0


## Whether this faction is hot enough to be seeking revenge.
func is_seeking_revenge(id: String) -> bool:
	return _factions.has(id) and float(_factions[id]["grudge"]) >= RETALIATE_AT


## The kind of strike this faction's current grudge would produce ("" if it isn't
## seeking revenge): vandalism -> property_raid -> hit_squad as the grudge rises.
func retaliation_kind_for(id: String) -> String:
	return _kind_for_grudge(grudge_of(id))


## 0..1 strength of a strike at the current grudge (for sizing damage / enemy count).
func retaliation_severity(id: String) -> float:
	return _severity_for_grudge(grudge_of(id))


# --- Provocation / pacification -------------------------------------------


## Raise a faction's grudge (turf taken, a hit, a heist hit). Negative amounts are
## ignored. Returns the new grudge, or -1.0 for an unknown faction.
func provoke(id: String, amount: float) -> float:
	if not _factions.has(id):
		return -1.0
	if amount > 0.0:
		_factions[id]["grudge"] = clampf(
			float(_factions[id]["grudge"]) + amount, MIN_GRUDGE, MAX_GRUDGE
		)
	return _factions[id]["grudge"]


## Cool a faction down (a truce, a pay-off). Negative amounts ignored. Returns the new
## grudge, or -1.0 for an unknown faction.
func pacify(id: String, amount: float) -> float:
	if not _factions.has(id):
		return -1.0
	if amount > 0.0:
		_factions[id]["grudge"] = maxf(float(_factions[id]["grudge"]) - amount, MIN_GRUDGE)
	return _factions[id]["grudge"]


# --- Time / retaliation ---------------------------------------------------


## Advance `delta_days`: every grudge fades by its decay rate, then each faction still
## seeking revenge whose strike cooldown has elapsed launches a retaliation. Returns
## {faction_id, kind, severity} for each strike this tick (spawn them at player
## holdings). Non-positive spans are ignored.
func tick(delta_days: float) -> Array:
	var strikes: Array = []
	if delta_days <= 0.0:
		return strikes
	for id: String in ids():
		var faction: Dictionary = _factions[id]
		# Use the grudge at the START of the span for the strike decision, so a long
		# time-skip still triggers the retaliation it earned before the grudge cools —
		# no avoidance by skipping time. Cooldown floors at 0 so saved state stays valid.
		var before: float = faction["grudge"]
		faction["grudge"] = maxf(before - float(faction["decay_per_day"]) * delta_days, MIN_GRUDGE)
		faction["cooldown"] = maxf(float(faction["cooldown"]) - delta_days, 0.0)
		if before >= RETALIATE_AT and float(faction["cooldown"]) <= 0.0:
			faction["cooldown"] = RETALIATION_COOLDOWN_DAYS
			(
				strikes
				. append(
					{
						"faction_id": id,
						"kind": _kind_for_grudge(before),
						"severity": _severity_for_grudge(before),
					}
				)
			)
	return strikes


# --- Persistence ----------------------------------------------------------


func serialize() -> Dictionary:
	var grudges: Dictionary = {}
	for id: String in ids():
		grudges[id] = {"grudge": _factions[id]["grudge"], "cooldown": _factions[id]["cooldown"]}
	return {"factions": grudges}


## Restore grudge + cooldown. Unknown ids dropped, values clamped; malformed input
## leaves the roster at defaults.
func restore(data: Dictionary) -> void:
	var stored: Variant = data.get("factions")
	if not (stored is Dictionary):
		return
	var grudges: Dictionary = stored
	for key: Variant in grudges:
		var id: String = str(key)
		if not _factions.has(id) or not (grudges[key] is Dictionary):
			continue
		var row: Dictionary = grudges[key]
		_factions[id]["grudge"] = clampf(float(row.get("grudge", 0.0)), MIN_GRUDGE, MAX_GRUDGE)
		_factions[id]["cooldown"] = maxf(float(row.get("cooldown", 0.0)), 0.0)


## Reset all grudges + cooldowns to calm.
func reset() -> void:
	for id: String in _factions:
		_factions[id]["grudge"] = 0.0
		_factions[id]["cooldown"] = RETALIATION_COOLDOWN_DAYS


# --- Internal -------------------------------------------------------------


## The strike kind for a grudge level ("" below RETALIATE_AT).
static func _kind_for_grudge(grudge: float) -> String:
	if grudge >= HIT_SQUAD_AT:
		return "hit_squad"
	if grudge >= RAID_AT:
		return "property_raid"
	if grudge >= RETALIATE_AT:
		return "vandalism"
	return ""


static func _severity_for_grudge(grudge: float) -> float:
	return clampf(grudge / MAX_GRUDGE, 0.0, 1.0)


## Validate and store one faction row; drops malformed (no/empty id) and duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _factions.has(id):
		return
	_factions[id] = {
		"decay_per_day": maxf(float(row.get("decay_per_day", DEFAULT_DECAY_PER_DAY)), 0.0),
		"grudge": 0.0,
		"cooldown": RETALIATION_COOLDOWN_DAYS,
	}
