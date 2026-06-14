class_name Romance
extends RefCounted
## Pure dating model — court a love interest by taking them on DATES. The hook: each partner LIKES
## a certain date type, so taking them somewhere they love builds affection fast while a mismatched
## venue barely moves it — you learn their taste. Reach COMMIT_AT and the relationship goes
## official (a one-time milestone). Distinct from FriendCircle (generic-quality rapport → one-shot
## perks) and ProtagonistBond (the two leads) by that preference-matching. No nodes, no wallet
## coupling (the caller charges the date + banks any milestone reward). Unit-tested headless
## (tests/unit/test_romance.gd).

const MIN_AFFECTION: float = 0.0
const MAX_AFFECTION: float = 1.0
## Affection gained by a date at their FAVOURITE venue vs a mismatched one.
const HIT_GAIN: float = 0.4
const MISS_GAIN: float = 0.05
## Affection at which the relationship becomes official.
const COMMIT_AT: float = 0.8
## Slack on the commit threshold so a date that SHOULD reach 0.8 isn't denied by float drift in
## an accumulation path (e.g. many small mismatched gains landing at 0.79999).
const COMMIT_EPSILON: float = 1e-5

## id -> {name, liked_date_type, affection}. Insertion-ordered.
var _partners: Dictionary = {}


func _init(partners: Array = []) -> void:
	var source: Array = partners if not partners.is_empty() else default_partners()
	for entry: Variant in source:
		_register(entry)


## Built-in love interests, each with a date type they love.
static func default_partners() -> Array:
	return [
		{"id": "alex", "name": "Alex", "liked_date_type": "dinner"},
		{"id": "sam", "name": "Sam", "liked_date_type": "club"},
		{"id": "rio", "name": "Rio", "liked_date_type": "drive"},
	]


# --- Queries -----------------------------------------------------------------


func partner_count() -> int:
	return _partners.size()


func has_partner(id: String) -> bool:
	return _partners.has(id)


func affection_of(id: String) -> float:
	return float(_partners[id]["affection"]) if _partners.has(id) else 0.0


func liked_type_of(id: String) -> String:
	return str(_partners[id]["liked_date_type"]) if _partners.has(id) else ""


## True once the relationship has reached COMMIT_AT (a state query — distinct from the one-time
## `committed` milestone event returned by date()).
func is_committed(id: String) -> bool:
	return _partners.has(id) and _meets_commit(float(_partners[id]["affection"]))


## Affection has reached the commit threshold (epsilon-slacked against float drift).
func _meets_commit(affection: float) -> bool:
	return affection >= COMMIT_AT - COMMIT_EPSILON


# --- Mutations ---------------------------------------------------------------


## Take a partner on a date of `date_type`. A date at their FAVOURITE type builds a lot of
## affection (a "hit"); a mismatch only a little. Returns {gain, affection, hit, committed} where
## `committed` is true ONLY on the date that first reaches COMMIT_AT.
func date(id: String, date_type: String) -> Dictionary:
	if not _partners.has(id):
		return {"gain": 0.0, "affection": 0.0, "hit": false, "committed": false}
	var was_committed := _meets_commit(float(_partners[id]["affection"]))
	var hit := date_type == str(_partners[id]["liked_date_type"])
	var gain := HIT_GAIN if hit else MISS_GAIN
	var affection := clampf(float(_partners[id]["affection"]) + gain, MIN_AFFECTION, MAX_AFFECTION)
	_partners[id]["affection"] = affection
	return {
		"gain": gain,
		"affection": affection,
		"hit": hit,
		"committed": _meets_commit(affection) and not was_committed,
	}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	var affections: Dictionary = {}
	for id: String in _partners:
		affections[id] = _partners[id]["affection"]
	return {"affection": affections}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var stored: Variant = (data as Dictionary).get("affection")
	if not (stored is Dictionary):
		return
	var affections: Dictionary = stored
	for key: Variant in affections:
		var id: String = str(key)
		if _partners.has(id):
			_partners[id]["affection"] = clampf(
				float(affections[key]), MIN_AFFECTION, MAX_AFFECTION
			)


# --- Internal ----------------------------------------------------------------


func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _partners.has(id):
		return
	_partners[id] = {
		"name": str(row.get("name", id)),
		"liked_date_type": str(row.get("liked_date_type", "dinner")),
		"affection": 0.0,
	}
