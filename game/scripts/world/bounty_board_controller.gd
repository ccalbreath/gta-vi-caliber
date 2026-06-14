class_name BountyBoardController
extends Node
## Owns the player's ONE bounty board (the most-wanted roster) and resolves a hunt at the
## player's live COMBAT RATING — a base competence lifted toward a crack shot by
## PlayerSkills.bonus("shooting"). So the high-bounty fugitives are gated behind training your
## shooting: this is the (abstracted, non-weapon) CONSUMER of the gym's shooting skill — the last
## of the four gym proficiencies to get one. Self-wires by group ("bounty_board"); BountyBoard
## zones attempt a fugitive against this shared roster. Banks the bounty to PlayerStats on a
## catch. Owns ONE BountyHunt (tests/unit/test_bounty_hunt.gd); verified bounty_hunt_probe.gd.

signal fugitive_caught(id: String, bounty: int)

## An untrained hunter's combat rating floor; the shooting skill lifts it the rest of the way.
const BASE_COMPETENCE: float = 0.4

var _hunt: BountyHunt


func _ready() -> void:
	_hunt = BountyHunt.new()
	add_to_group("bounty_board")


## The player's combat rating (0..1): BASE_COMPETENCE lifted toward 1.0 by the shooting skill (0
## when no skills node is wired, so an untrained hunter sits at the floor).
func combat_rating() -> float:
	var skills := get_tree().get_first_node_in_group("player_skills")
	var shooting := 0.0
	if skills != null and skills.has_method("bonus"):
		shooting = clampf(float(skills.bonus("shooting")), 0.0, 1.0)
	return clampf(BASE_COMPETENCE + shooting * (1.0 - BASE_COMPETENCE), 0.0, 1.0)


## Attempt to bring a fugitive in at the current combat rating. On a catch, banks the bounty to
## PlayerStats. The wallet is guarded BEFORE the catch commits, so a fugitive is never marked
## caught without paying out. Returns the bounty (>0) on a catch, 0 when OUTGUNNED (they got
## away), or -1 when the hunt couldn't be resolved at all (unknown / already caught / no wallet)
## — the caller distinguishes a real escape from a system no-op.
func attempt(id: String) -> int:
	if _hunt == null or not _hunt.has_fugitive(id) or _hunt.is_caught(id):
		return -1
	var rating := combat_rating()
	if rating < _hunt.difficulty_of(id):
		return 0  # outgunned — they get away; train up and come back
	var stats := get_tree().get_first_node_in_group("player_stats")
	if stats == null or not stats.has_method("add_money"):
		return -1  # can't bank the bounty — leave the fugitive at large, silently
	var result := _hunt.attempt(id, rating)
	if not bool(result["success"]):
		return -1
	var bounty := int(result["bounty"])
	stats.add_money(bounty)
	fugitive_caught.emit(id, bounty)
	return bounty


# --- Queries (passthroughs for the boards / HUD) -----------------------------


func is_caught(id: String) -> bool:
	return _hunt != null and _hunt.is_caught(id)


func bounty_of(id: String) -> int:
	return _hunt.bounty_of(id) if _hunt != null else 0


func difficulty_of(id: String) -> float:
	return _hunt.difficulty_of(id) if _hunt != null else 0.0


func open_count() -> int:
	return _hunt.open_count() if _hunt != null else 0
