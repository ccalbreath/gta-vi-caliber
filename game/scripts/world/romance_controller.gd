class_name RomanceController
extends Node
## Owns the player's ONE love life and runs a date against PlayerStats: pay the tab, then build
## the partner's affection (a lot at their favourite kind of venue). When the relationship reaches
## commitment it pays a one-time milestone reward. Self-wires by group ("romance"); DateSpot zones
## run a date against this shared model. The tab is charged BEFORE the date AND must be positive,
## so a free date can't court your way to the reward. Owns ONE Romance
## (tests/unit/test_romance.gd); verified romance_probe.gd.

signal dated(id: String, affection: float, hit: bool)
signal committed(id: String, gift: int)

## One-time reward when a relationship goes official.
const COMMIT_GIFT: int = 3000

var _romance: Romance


func _ready() -> void:
	_romance = Romance.new()
	add_to_group("romance")


## Take a partner on a date of `date_type`, charging `cost` to PlayerStats. Returns the affection
## afterward. A date that reaches commitment pays the one-time gift. Non-positive cost / a short
## wallet / an unknown partner are no-ops (no affection built).
func go_on_date(id: String, date_type: String, cost: int) -> float:
	if _romance == null or not _romance.has_partner(id) or cost <= 0:
		return _romance.affection_of(id) if _romance != null else 0.0
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("spend_money") or not stats.has_method("add_money"):
		return _romance.affection_of(id)
	if not stats.spend_money(cost):
		return _romance.affection_of(id)  # can't cover the tab — no date
	var result := _romance.date(id, date_type)
	if bool(result["committed"]):
		stats.add_money(COMMIT_GIFT)
		committed.emit(id, COMMIT_GIFT)
	dated.emit(id, float(result["affection"]), bool(result["hit"]))
	return float(result["affection"])


# --- Queries (passthroughs for the zones / HUD) ------------------------------


func affection_of(id: String) -> float:
	return _romance.affection_of(id) if _romance != null else 0.0


func liked_type_of(id: String) -> String:
	return _romance.liked_type_of(id) if _romance != null else ""


func is_committed(id: String) -> bool:
	return _romance != null and _romance.is_committed(id)


func partner_count() -> int:
	return _romance.partner_count() if _romance != null else 0
