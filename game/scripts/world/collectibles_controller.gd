class_name CollectiblesController
extends Node
## Owns the player's ONE collectible SET (the hidden-package hunt) and banks each find. Self-
## wires by group ("collection"); Collectible zones report a find against this one shared set, so
## the map's whole hunt is one state. Each find pays its bounty to PlayerStats; finding the LAST
## one pays the big SET-COMPLETE bonus. No day-clock — a found item stays found. Drives the
## tested CollectionSet model (tests/unit/test_collection_set.gd); verified collectibles_probe.gd.

signal collected(id: String, reward: int, found_count: int, total: int)
signal set_completed(bonus: int)

## Optional custom roster (rows {id, reward}); empty uses the model's default hidden packages.
@export var items: Array = []
@export var set_bonus: int = CollectionSet.DEFAULT_SET_BONUS

var _set: CollectionSet


func _ready() -> void:
	_set = CollectionSet.new(items, set_bonus)
	add_to_group("collection")


## Report a collectible found. Banks its reward (+ the set bonus if it completes the hunt) to
## PlayerStats. Guards the wallet BEFORE marking it found, so a collectible is never consumed
## without paying out. Returns the total paid (0 if already found / unknown / no wallet).
func collect(id: String) -> int:
	if _set == null or not _set.has_item(id) or _set.is_found(id):
		return 0
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return 0  # can't bank it — leave the collectible grabbable for later
	var result := _set.find(id)
	var paid := int(result["reward"]) + int(result["set_bonus"])
	stats.add_money(paid)
	collected.emit(id, int(result["reward"]), int(result["found_count"]), _set.total())
	if int(result["set_bonus"]) > 0:
		set_completed.emit(int(result["set_bonus"]))
	return paid


# --- Queries (passthroughs for the zones / HUD) ------------------------------


func is_found(id: String) -> bool:
	return _set != null and _set.is_found(id)


func found_count() -> int:
	return _set.found_count() if _set != null else 0


func total() -> int:
	return _set.total() if _set != null else 0


func remaining() -> int:
	return _set.remaining() if _set != null else 0


func is_complete() -> bool:
	return _set != null and _set.is_complete()


func progress() -> float:
	return _set.progress() if _set != null else 0.0
