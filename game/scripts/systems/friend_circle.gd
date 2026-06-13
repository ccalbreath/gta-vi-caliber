class_name FriendCircle
extends RefCounted
## The player's named-NPC friendships — the GTA "hang out with Roman/Lamar" social
## circle. Each friend has a rapport level you build by hanging out and burn by
## standing them up; let it fall idle and it cools on its own. Once a friendship
## reaches CLOSE, that friend's PERK unlocks — a standing favour you can call in
## for free (a discount mechanic, free wheels, muscle for a fight, a gun runner,
## street intel — whatever perk the friend was given).
##
## Distinct axes from the neighbours: `ContactServices` is a paid, cooldown-gated
## transaction; `NpcCompliance` is coercing strangers; `ProtagonistBond` is the two
## leads. This is an EARNED, persistent bond with specific people that gates FREE
## perks. Pure + deterministic — unit-tested headless (tests/unit/test_friend_circle.gd).
## A hangout activity calls hang_out(); a phone "hang out / call a friend" UI reads
## perk_unlocked()/perk_of() to offer the favour; a day tick calls decay().
## Persisted via to_dict/from_dict.

const RAPPORT_MIN: float = 0.0
const RAPPORT_MAX: float = 100.0
## A fresh friend starts as an acquaintance.
const START_RAPPORT: float = 20.0
## Rapport gained from a full-quality hangout, lost from a full-severity slight.
const HANG_GAIN: float = 15.0
const SLIGHT_LOSS: float = 25.0
## Rapport shed per in-game day a friend is ignored.
const DECAY_PER_DAY: float = 1.5

# Friendship-tier thresholds (lower bound).
const TIER_FRIEND: float = 30.0
const TIER_CLOSE: float = 60.0
const TIER_BEST: float = 85.0
## Tier at/above which a friend's perk is available.
const PERK_TIER: float = TIER_CLOSE

var _friends: Dictionary = {}  # id -> {name, rapport, perk}

# --- Roster ------------------------------------------------------------------


func befriend(id: String, name: String, perk: String = "") -> bool:
	var clean_id := id.strip_edges()
	if clean_id.is_empty() or _friends.has(clean_id):
		return false
	_friends[clean_id] = {"name": name, "rapport": START_RAPPORT, "perk": perk}
	return true


func has_friend(id: String) -> bool:
	return _friends.has(id)


func circle_size() -> int:
	return _friends.size()


# --- Queries -----------------------------------------------------------------


func rapport_of(id: String) -> float:
	if not _friends.has(id):
		return 0.0
	return _friends[id]["rapport"]


func tier_of(id: String) -> String:
	var r := rapport_of(id)
	if r >= TIER_BEST:
		return "best"
	if r >= TIER_CLOSE:
		return "close"
	if r >= TIER_FRIEND:
		return "friend"
	return "acquaintance"


## True once the friendship is close enough to call in that friend's standing favour.
func perk_unlocked(id: String) -> bool:
	return _friends.has(id) and rapport_of(id) >= PERK_TIER


func perk_of(id: String) -> String:
	if not _friends.has(id):
		return ""
	return _friends[id]["perk"]


## Highest-rapport friend's id, or "" if the circle is empty.
func best_friend() -> String:
	var best_id := ""
	var best_rapport := -1.0
	for id in _friends:
		var r: float = _friends[id]["rapport"]
		if r > best_rapport:
			best_rapport = r
			best_id = id
	return best_id


# --- Mutations (return the new rapport, or -1 for an unknown friend) ----------


## A hangout/activity together. [param quality] ~0..1 (a wild night out > a text).
func hang_out(id: String, quality: float = 1.0) -> float:
	return _shift(id, HANG_GAIN * maxf(quality, 0.0))


## Standing them up, hurting them, choosing a rival over them. [param severity] ~0..1.
func slight(id: String, severity: float = 1.0) -> float:
	return _shift(id, -SLIGHT_LOSS * maxf(severity, 0.0))


## Idle friendships cool toward zero (out of sight, out of mind).
func decay(days: float = 1.0) -> void:
	if days <= 0.0:
		return
	var step := DECAY_PER_DAY * days
	for id in _friends:
		_friends[id]["rapport"] = maxf(float(_friends[id]["rapport"]) - step, RAPPORT_MIN)


func _shift(id: String, amount: float) -> float:
	if not _friends.has(id):
		return -1.0
	var r := clampf(float(_friends[id]["rapport"]) + amount, RAPPORT_MIN, RAPPORT_MAX)
	_friends[id]["rapport"] = r
	return r


# --- Persistence -------------------------------------------------------------


func to_dict() -> Dictionary:
	return {"friends": _friends.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_friends.clear()
	var saved: Dictionary = data.get("friends", {})
	for id in saved:
		var f: Dictionary = saved[id]
		_friends[id] = {
			"name": str(f.get("name", id)),
			"rapport": clampf(float(f.get("rapport", START_RAPPORT)), RAPPORT_MIN, RAPPORT_MAX),
			"perk": str(f.get("perk", "")),
		}
