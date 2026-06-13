class_name NpcCompliance
extends RefCounted
## Pure per-NPC bribe / intimidate / persuade decision model — the transactional
## "lean on one person" layer, distinct from FactionStanding's per-faction reputation.
## Each tracked NPC carries a 0..1 compliance state (how cooperative they are toward
## the player right now) split into a DURABLE part and a decaying intimidation
## PRESSURE, plus a fixed disposition (greed, fearfulness, stubbornness). Three
## channels shift compliance:
##   - bribe(): pay cash — effectiveness scales with greed, diminishes as you over-pay
##     and as compliance rises; DURABLE.
##   - intimidate(): threaten — menace blended from player notoriety + weapon menace,
##     amplified by fearfulness, resisted by stubbornness; builds fast but DECAYS via
##     decay() as the threat memory fades.
##   - persuade(): talk — scaled by charisma, resisted by stubbornness; slow, free,
##     DURABLE.
## Crossing FAVOUR_GATE makes the NPC grant a favour (info / look away / hand over an
## item); the stricter SILENCE_GATE makes a witness keep quiet — the seam a
## CrimeWitness/WantedTracker check reads BEFORE counting a witness, so a paid-off or
## terrified bystander doesn't raise heat.
##
## No nodes, no hard coupling: callers pass derived 0..1 scalars (WantedSystem stars
## via notoriety_from_stars(), PlayerProgression level via charisma_from_progression(),
## a weapon menace from WeaponLoadout), and the bribe wallet result is applied by the
## caller (PlayerStats.spend_money) — same contract as PropertyOwnership/ChopShop.
## Unit-tested headless (tests/unit/test_npc_compliance.gd).
##
## Roster row: {id, greed, fearfulness, stubbornness, compliance?}. Rows with a
## missing/empty id, or a duplicate id, are dropped; traits are clamped to 0..1.

## Compliance a freshly-met NPC starts at (slightly cooperative).
const COMPLIANCE_START: float = 0.1
## Gate thresholds: a favour is easier to earn than a witness's silence.
const FAVOUR_GATE: float = 0.5
const SILENCE_GATE: float = 0.75
## Talking alone tops out here (below SILENCE_GATE): persuasion earns favours, never a
## witness's silence — that needs cash (bribe) or fear (intimidate).
const PERSUADE_CAP: float = 0.65
## Intimidation pressure bleeds off at this much compliance per second.
const INTIMIDATION_DECAY_PER_SEC: float = 0.05
## Cash amount at/above which a bribe has full effect (over-paying past it is wasted).
const BRIBE_FULL_AMOUNT: float = 1000.0
## Per-channel maximum single-call gain (before disposition + diminishing scaling).
const BRIBE_MAX_GAIN: float = 0.6
const INTIMIDATE_MAX_GAIN: float = 0.7
const PERSUADE_MAX_GAIN: float = 0.4
## Notoriety vs weapon weighting when blending intimidation menace.
const NOTORIETY_MENACE_WEIGHT: float = 0.6
## Below this single-call gain an intimidation "doesn't budge" the NPC (fails).
const MIN_DELTA: float = 0.001

## id -> {greed, fearfulness, stubbornness, durable: float, pressure: float}.
var _npcs: Dictionary = {}


func _init(npcs: Array = []) -> void:
	var source: Array = npcs if not npcs.is_empty() else default_npcs()
	for entry: Variant in source:
		_register(entry)


## Built-in archetype roster: a greedy fixer, a scared bystander, a hardened thug
## (stubborn + fearless), and a neutral local.
static func default_npcs() -> Array:
	return [
		{"id": "greedy_fixer", "greed": 0.9, "fearfulness": 0.3, "stubbornness": 0.3},
		{"id": "scared_bystander", "greed": 0.3, "fearfulness": 0.9, "stubbornness": 0.2},
		{"id": "hardened_thug", "greed": 0.2, "fearfulness": 0.1, "stubbornness": 0.9},
		{"id": "neutral_local", "greed": 0.5, "fearfulness": 0.5, "stubbornness": 0.5},
	]


# --- Roster ---------------------------------------------------------------


func npc_count() -> int:
	return _npcs.size()


func has_npc(id: String) -> bool:
	return _npcs.has(id)


## Registered ids, sorted for determinism.
func ids() -> Array:
	var out: Array = _npcs.keys()
	out.sort()
	return out


## Add one NPC at runtime (e.g. when a ped spawns). False if the id is empty or a
## duplicate. Traits are clamped to 0..1; compliance starts at COMPLIANCE_START.
func register_npc(id: String, profile: Dictionary = {}) -> bool:
	if id.is_empty() or _npcs.has(id):
		return false
	_npcs[id] = {
		"greed": _trait(profile.get("greed", 0.5)),
		"fearfulness": _trait(profile.get("fearfulness", 0.5)),
		"stubbornness": _trait(profile.get("stubbornness", 0.5)),
		"durable": COMPLIANCE_START,
		"pressure": 0.0,
	}
	return true


# --- Disposition / state queries (neutral for unknown ids) ----------------


func greed_of(id: String) -> float:
	return _npcs[id]["greed"] if _npcs.has(id) else 0.0


func fearfulness_of(id: String) -> float:
	return _npcs[id]["fearfulness"] if _npcs.has(id) else 0.0


func stubbornness_of(id: String) -> float:
	return _npcs[id]["stubbornness"] if _npcs.has(id) else 0.0


## Current 0..1 cooperative state (durable + decaying pressure, clamped). 0 if unknown.
func compliance_of(id: String) -> float:
	if not _npcs.has(id):
		return 0.0
	return clampf(float(_npcs[id]["durable"]) + float(_npcs[id]["pressure"]), 0.0, 1.0)


# --- Channels -------------------------------------------------------------


## Pay cash to raise compliance (durable). Gain scales with greed and the amount
## (saturating at BRIBE_FULL_AMOUNT — over-paying wastes money) and diminishes as
## compliance rises. Returns {success, cost, new_balance, compliance, delta, reason}.
## Fails (cost 0, balance unchanged) for unknown id / non-positive amount /
## amount > balance / an already-maxed NPC.
func bribe(id: String, amount: int, balance: int) -> Dictionary:
	if not _npcs.has(id):
		return _fail(balance, "unknown npc: %s" % id)
	if amount <= 0:
		return _fail(balance, "non-positive amount", compliance_of(id))
	if amount > balance:
		return _fail(
			balance, "insufficient funds: need %d, have %d" % [amount, balance], compliance_of(id)
		)
	var before: float = compliance_of(id)
	if before >= 1.0 - MIN_DELTA:
		return _fail(balance, "already fully compliant", 1.0)
	var amount_factor: float = clampf(float(amount) / BRIBE_FULL_AMOUNT, 0.0, 1.0)
	var gain: float = float(_npcs[id]["greed"]) * amount_factor * BRIBE_MAX_GAIN * (1.0 - before)
	_npcs[id]["durable"] = float(_npcs[id]["durable"]) + gain
	var after: float = compliance_of(id)
	return {
		"success": true,
		"cost": amount,
		"new_balance": balance - amount,
		"compliance": after,
		"delta": after - before,
		"reason": "",
	}


## Threaten the NPC. Menace blends player notoriety (0..1) and weapon menace (0..1);
## the gain is amplified by fearfulness, resisted by stubbornness, and added as
## decaying PRESSURE. Returns {success, compliance, delta, menace, reason}. Fails
## (delta 0) for unknown id, zero menace, or an NPC too stubborn/calm to budge.
func intimidate(id: String, notoriety: float, weapon_menace: float) -> Dictionary:
	if not _npcs.has(id):
		return {
			"success": false,
			"compliance": 0.0,
			"delta": 0.0,
			"menace": 0.0,
			"reason": "unknown npc"
		}
	var menace: float = clampf(
		(
			NOTORIETY_MENACE_WEIGHT * clampf(notoriety, 0.0, 1.0)
			+ (1.0 - NOTORIETY_MENACE_WEIGHT) * clampf(weapon_menace, 0.0, 1.0)
		),
		0.0,
		1.0
	)
	var before: float = compliance_of(id)
	if menace <= 0.0:
		return {
			"success": false,
			"compliance": before,
			"delta": 0.0,
			"menace": 0.0,
			"reason": "no menace"
		}
	var resist: float = 1.0 - float(_npcs[id]["stubbornness"])
	# Intimidation can never push pressure past a disposition ceiling, so a fearless,
	# stubborn NPC (the hardened thug) barely budges no matter how often you lean on them.
	var max_pressure: float = float(_npcs[id]["fearfulness"]) * resist
	var current_pressure: float = float(_npcs[id]["pressure"])
	var gain: float = (
		menace * float(_npcs[id]["fearfulness"]) * resist * INTIMIDATE_MAX_GAIN * (1.0 - before)
	)
	gain = minf(gain, max_pressure - current_pressure)
	if gain < MIN_DELTA:
		return {
			"success": false,
			"compliance": before,
			"delta": 0.0,
			"menace": menace,
			"reason": "won't budge"
		}
	_npcs[id]["pressure"] = current_pressure + gain
	var after: float = compliance_of(id)
	return {
		"success": true,
		"compliance": after,
		"delta": after - before,
		"menace": menace,
		"reason": "",
	}


## Talk the NPC round (durable). Gain scales with charisma (0..1, derive via
## charisma_from_progression), resisted by stubbornness, and CAPPED at PERSUADE_CAP so
## talking earns favours but never a witness's silence. Returns
## {success, compliance, delta, reason}. Fails for an unknown id, a fully-talked-round
## NPC (at the cap), or negligible charisma.
func persuade(id: String, charisma: float) -> Dictionary:
	if not _npcs.has(id):
		return {"success": false, "compliance": 0.0, "delta": 0.0, "reason": "unknown npc"}
	var before: float = compliance_of(id)
	if before >= PERSUADE_CAP:
		return {
			"success": false,
			"compliance": before,
			"delta": 0.0,
			"reason": "won't be talked round further"
		}
	var resist: float = 1.0 - float(_npcs[id]["stubbornness"])
	var gain: float = clampf(charisma, 0.0, 1.0) * resist * PERSUADE_MAX_GAIN * (1.0 - before)
	gain = minf(gain, PERSUADE_CAP - before)  # talking alone can't reach the silence bar
	if gain < MIN_DELTA:
		return {
			"success": false, "compliance": before, "delta": 0.0, "reason": "not persuasive enough"
		}
	_npcs[id]["durable"] = float(_npcs[id]["durable"]) + gain
	var after: float = compliance_of(id)
	return {"success": true, "compliance": after, "delta": after - before, "reason": ""}


## Map a PlayerProgression level to a 0..1 charisma so callers don't hardcode the curve.
static func charisma_from_progression(level: int, max_level: int) -> float:
	if max_level <= 0:
		return 0.0
	return clampf(float(level) / float(max_level), 0.0, 1.0)


## Map WantedSystem stars (0..5) to a 0..1 notoriety scalar for intimidate().
static func notoriety_from_stars(stars: int) -> float:
	return clampf(float(stars) / 5.0, 0.0, 1.0)


# --- Gates ----------------------------------------------------------------


## The NPC will grant a favour (info / look away / item).
func will_grant_favour(id: String) -> bool:
	return compliance_of(id) >= FAVOUR_GATE


## The NPC will stay quiet as a witness (a stricter bar than a favour). A
## CrimeWitness gate reads this before counting the bystander toward heat.
func will_silence_witness(id: String) -> bool:
	return compliance_of(id) >= SILENCE_GATE


# --- Time / lifecycle -----------------------------------------------------


## Advance `delta` seconds: intimidation pressure bleeds back toward its floor
## (bribe/persuade gains are durable and untouched). Pressure never goes < 0.
func decay(delta: float) -> void:
	if delta <= 0.0:
		return
	var bleed: float = INTIMIDATION_DECAY_PER_SEC * delta
	for id: String in _npcs:
		_npcs[id]["pressure"] = maxf(float(_npcs[id]["pressure"]) - bleed, 0.0)


## Reset one NPC to a fresh encounter (compliance + pressure back to start).
func reset_npc(id: String) -> void:
	if not _npcs.has(id):
		return
	_npcs[id]["durable"] = COMPLIANCE_START
	_npcs[id]["pressure"] = 0.0


# --- Persistence ----------------------------------------------------------


func serialize() -> Dictionary:
	var npcs: Dictionary = {}
	for id: String in ids():
		npcs[id] = {"durable": _npcs[id]["durable"], "pressure": _npcs[id]["pressure"]}
	return {"npcs": npcs}


## Rebuild durable/pressure from a serialize() snapshot. Unknown ids dropped, values
## clamped; malformed input leaves the roster at its registered defaults.
func restore(data: Dictionary) -> void:
	var stored: Variant = data.get("npcs")
	if not (stored is Dictionary):
		return
	var npcs: Dictionary = stored
	for key: Variant in npcs:
		var id: String = str(key)
		if not _npcs.has(id) or not (npcs[key] is Dictionary):
			continue
		var row: Dictionary = npcs[key]
		if _is_num(row.get("durable")):
			_npcs[id]["durable"] = clampf(float(row["durable"]), 0.0, 1.0)
		if _is_num(row.get("pressure")):
			_npcs[id]["pressure"] = clampf(float(row["pressure"]), 0.0, 1.0)


# --- Internal -------------------------------------------------------------


static func _is_num(value: Variant) -> bool:
	return value is float or value is int


static func _trait(value: Variant) -> float:
	return clampf(float(value), 0.0, 1.0) if _is_num(value) else 0.5


func _fail(balance: int, reason: String, current: float = 0.0) -> Dictionary:
	return {
		"success": false,
		"cost": 0,
		"new_balance": balance,
		"compliance": current,
		"delta": 0.0,
		"reason": reason,
	}


## Validate and store one roster row; drops malformed (no/empty id) and duplicates.
func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _npcs.has(id):
		return
	_npcs[id] = {
		"greed": _trait(row.get("greed", 0.5)),
		"fearfulness": _trait(row.get("fearfulness", 0.5)),
		"stubbornness": _trait(row.get("stubbornness", 0.5)),
		"durable": _trait(row.get("compliance", COMPLIANCE_START)),
		"pressure": 0.0,
	}
