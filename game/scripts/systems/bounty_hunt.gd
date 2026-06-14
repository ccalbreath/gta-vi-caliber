class_name BountyHunt
extends RefCounted
## Pure bounty-hunting model — work FOR the law, hauling wanted fugitives in for cash. A roster
## of fugitives, each with a BOUNTY and a DIFFICULTY (how dangerous/skilled they are); you bring
## one in only if your COMBAT RATING meets their difficulty, so the big bounties are locked behind
## being a better shot — a skill gate. Distinct from PlayerBounty (a price on YOU) and
## HitContractBoard (assassination-for-hire). The combat rating is an ABSTRACTED skill check (no
## weapon/scene coupling), fed by the caller from PlayerSkills.bonus("shooting"). Deterministic,
## no nodes, no wallet coupling. Unit-tested headless (tests/unit/test_bounty_hunt.gd).

## id -> {name, bounty, difficulty, caught}. Insertion-ordered.
var _fugitives: Dictionary = {}


func _init(fugitives: Array = []) -> void:
	var source: Array = fugitives if not fugitives.is_empty() else default_fugitives()
	for entry: Variant in source:
		_register(entry)


## Built-in most-wanted board: bounty climbs with danger (difficulty 0..1).
static func default_fugitives() -> Array:
	return [
		{"id": "petty_thief", "name": "Petty Thief", "bounty": 2000, "difficulty": 0.2},
		{"id": "armed_robber", "name": "Armed Robber", "bounty": 6000, "difficulty": 0.5},
		{"id": "gang_lieutenant", "name": "Gang Lieutenant", "bounty": 15000, "difficulty": 0.75},
		{"id": "cop_killer", "name": "Cop-Killer", "bounty": 40000, "difficulty": 0.95},
	]


# --- Queries -----------------------------------------------------------------


func fugitive_count() -> int:
	return _fugitives.size()


func has_fugitive(id: String) -> bool:
	return _fugitives.has(id)


func bounty_of(id: String) -> int:
	return int(_fugitives[id]["bounty"]) if _fugitives.has(id) else 0


func difficulty_of(id: String) -> float:
	return float(_fugitives[id]["difficulty"]) if _fugitives.has(id) else 0.0


func is_caught(id: String) -> bool:
	return _fugitives.has(id) and bool(_fugitives[id]["caught"])


## Fugitives still at large.
func open_count() -> int:
	var count := 0
	for id: String in _fugitives:
		if not bool(_fugitives[id]["caught"]):
			count += 1
	return count


# --- Mutations ---------------------------------------------------------------


## Try to bring a fugitive in at `combat_rating` (0..1). Caught (bounty banked by the caller) iff
## the rating MEETS their difficulty and they're still at large; otherwise they get away (a
## retry is allowed once you're a better shot). Returns {success, bounty, reason}.
func attempt(id: String, combat_rating: float) -> Dictionary:
	if not _fugitives.has(id):
		return {"success": false, "bounty": 0, "reason": "unknown fugitive"}
	if bool(_fugitives[id]["caught"]):
		return {"success": false, "bounty": 0, "reason": "already caught"}
	if combat_rating < float(_fugitives[id]["difficulty"]):
		return {"success": false, "bounty": 0, "reason": "outgunned — they got away"}
	_fugitives[id]["caught"] = true
	return {"success": true, "bounty": int(_fugitives[id]["bounty"]), "reason": ""}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	var caught: Array = []
	for id: String in _fugitives:
		if bool(_fugitives[id]["caught"]):
			caught.append(id)
	return {"caught": caught}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var stored: Variant = (data as Dictionary).get("caught")
	if not (stored is Array):
		return
	for entry: Variant in stored:
		var id: String = str(entry)
		if _fugitives.has(id):
			_fugitives[id]["caught"] = true


# --- Internal ----------------------------------------------------------------


func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _fugitives.has(id):
		return
	var bounty: int = int(row.get("bounty", 0))
	if bounty <= 0:
		return
	_fugitives[id] = {
		"name": str(row.get("name", id)),
		"bounty": bounty,
		"difficulty": clampf(float(row.get("difficulty", 0.5)), 0.0, 1.0),
		"caught": false,
	}
