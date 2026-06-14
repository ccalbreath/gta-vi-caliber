class_name CollectionSet
extends RefCounted
## Pure collectibles model — the GTA hidden-package / stunt-jump SET: a fixed roster of items
## scattered across the map; finding each pays a small bounty, and finding the LAST one pays a
## big SET-COMPLETE bonus. A progressive-completion loop, distinct from the one-shot
## transactions and day-clock rackets. No nodes, no wallet coupling (the caller credits
## PlayerStats with the returned reward + set_bonus). Deterministic, unit-tested headless
## (tests/unit/test_collection_set.gd).

const DEFAULT_ITEM_REWARD: int = 250
const DEFAULT_SET_BONUS: int = 25000
const DEFAULT_COUNT: int = 10

## id -> {reward, found}. Insertion-ordered.
var _items: Dictionary = {}
## One-time payout for finding every item in the set (read-only after construction).
var _set_bonus: int


func _init(items: Array = [], bonus: int = DEFAULT_SET_BONUS) -> void:
	_set_bonus = maxi(bonus, 0)
	var source: Array = items if not items.is_empty() else default_items()
	for entry: Variant in source:
		_register(entry)


## Built-in roster: DEFAULT_COUNT hidden packages, each a flat bounty.
static func default_items() -> Array:
	var out: Array = []
	for i in DEFAULT_COUNT:
		out.append({"id": "package_%d" % i, "reward": DEFAULT_ITEM_REWARD})
	return out


# --- Queries -----------------------------------------------------------------


func total() -> int:
	return _items.size()


func has_item(id: String) -> bool:
	return _items.has(id)


func is_found(id: String) -> bool:
	return _items.has(id) and bool(_items[id]["found"])


func found_count() -> int:
	var count := 0
	for id: String in _items:
		if bool(_items[id]["found"]):
			count += 1
	return count


func remaining() -> int:
	return total() - found_count()


func is_complete() -> bool:
	return total() > 0 and found_count() == total()


## 0..1 share of the set found.
func progress() -> float:
	return float(found_count()) / float(total()) if total() > 0 else 0.0


# --- Mutations ---------------------------------------------------------------


## Find a collectible: the first find marks it and pays its reward, and the find that COMPLETES
## the set also pays set_bonus. A re-find (or unknown id) is an inert no-op. Returns
## {newly_found, reward, set_bonus, found_count, complete}.
func find(id: String) -> Dictionary:
	if not _items.has(id) or bool(_items[id]["found"]):
		return _state(false, 0, 0)
	_items[id]["found"] = true
	var reward: int = int(_items[id]["reward"])
	var bonus: int = _set_bonus if is_complete() else 0
	return _state(true, reward, bonus)


func _state(newly_found: bool, reward: int, bonus: int) -> Dictionary:
	return {
		"newly_found": newly_found,
		"reward": reward,
		"set_bonus": bonus,
		"found_count": found_count(),
		"complete": is_complete(),
	}


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	var found: Array = []
	for id: String in _items:
		if bool(_items[id]["found"]):
			found.append(id)
	return {"found": found}


func from_dict(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var stored: Variant = (data as Dictionary).get("found")
	if not (stored is Array):
		return
	for entry: Variant in stored:
		var id: String = str(entry)
		if _items.has(id):
			_items[id]["found"] = true


# --- Internal ----------------------------------------------------------------


func _register(entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var row: Dictionary = entry
	if not row.has("id"):
		return
	var id: String = str(row["id"])
	if id.is_empty() or _items.has(id):
		return
	_items[id] = {"reward": maxi(int(row.get("reward", DEFAULT_ITEM_REWARD)), 0), "found": false}
