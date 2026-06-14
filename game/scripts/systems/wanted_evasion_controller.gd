class_name WantedEvasionController
extends Node
## Closes the wanted loop: escalation already works (crime -> stars -> police);
## this adds de-escalation by EVASION. While the police can still see the player
## the heat holds; once the player breaks line of sight, a search countdown runs
## and the wanted level clears when the player has stayed unseen long enough
## ("go cold"). Drives the pure, tested WantedEvasion model from live police
## sightlines. Self-wires by group (player, wanted, police, social_clout) — no scene
## plumbing. A FAMOUS player (SocialClout.recognizability) is recognized on sight, so the
## search gives up SLOWER — the price of going viral.

## Go-cold drain multiplier at full recognizability: a maximally viral player drains the
## search countdown at this rate while unseen (0.5 = takes ~twice as long to shake the
## cops). 1.0 would mean fame has no effect.
const MIN_FAME_DRAIN: float = 0.5

## Officers beyond this planar range can't see the player.
@export var sight_radius: float = 50.0
## Eye height for the sightline ray (matches the player camera / cop eye).
@export var eye_height: float = 1.6
## Seconds unseen before the player goes cold and the stars drop.
@export var search_duration: float = 8.0

var _evasion: WantedEvasion
var _tracker: Node = null
var _player: Node3D = null
var _disguise: Node = null
var _clout: Node = null
var _was_seen: bool = false


func _ready() -> void:
	_evasion = WantedEvasion.new(search_duration)
	add_to_group("wanted_evasion")


func _physics_process(delta: float) -> void:
	_bind()
	if _player == null or _tracker == null or not _tracker.has_method("is_wanted"):
		return
	if not _tracker.is_wanted():
		# Not wanted: nothing to evade, keep the timer primed for next time.
		_evasion.reset()
		_was_seen = false
		return
	var seen := _seen_by_police()
	# The moment the cops first lay eyes on the player, stamp the description they'll
	# hunt — so recognition() is meaningful and CHANGING clothes afterward is what
	# earns the evasion bonus (not merely owning a disguise).
	if seen and not _was_seen and _disguise != null and _disguise.has_method("log_sighting"):
		_disguise.log_sighting()
	_was_seen = seen
	# A disguised player drains the "go cold" countdown faster (Disguise.evasion_speedup,
	# 1x..3x); a famous one drains it slower (recognized on sight) — both only while
	# unseen, since being seen resets the timer regardless of step.
	var step := delta if seen else delta * _disguise_speedup() * _recognizability_slowdown()
	_evasion.update(seen, step)
	if _evasion.is_cold() and _tracker.has_method("clear"):
		_tracker.clear()
		_evasion.reset()


## Search-drain multiplier from the player's Disguise (group "player_disguise"):
## 1.0 when none is wired or the player still matches the cops' description, up to
## Disguise.MAX_EVASION_SPEEDUP when fully disguised. Clamped both ends so a stray
## node in the group can't slow evasion below normal OR snap the player cold.
func _disguise_speedup() -> float:
	if _disguise != null and _disguise.has_method("evasion_speedup"):
		return clampf(float(_disguise.evasion_speedup()), 1.0, Disguise.MAX_EVASION_SPEEDUP)
	return 1.0


## Go-cold SLOWDOWN from the player's public fame (group "social_clout"): 1.0 when none is
## wired (no effect — fully behaviour-preserving), down to MIN_FAME_DRAIN when fully
## recognizable, since a viral player is spotted on sight so the search takes longer to give
## up. Clamped so a stray node can't speed evasion up or stall the timer dead.
func _recognizability_slowdown() -> float:
	if _clout != null and _clout.has_method("recognizability"):
		var fame := clampf(float(_clout.recognizability()), 0.0, 1.0)
		# Floor the result so a mis-set MIN_FAME_DRAIN of 0 can't freeze the cold timer (a
		# soft-lock) — symmetric to the 1.0 floor _disguise_speedup keeps on its side.
		return maxf(lerpf(1.0, MIN_FAME_DRAIN, fame), 0.01)
	return 1.0


## 0 while in sight, ramping to 1 as the player nears going cold (HUD star flash).
func search_progress() -> float:
	return _evasion.search_progress() if _evasion != null else 0.0


func is_searching() -> bool:
	return _evasion != null and _evasion.is_searching()


func _bind() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _tracker == null or not is_instance_valid(_tracker):
		_tracker = get_tree().get_first_node_in_group("wanted")
	if _disguise == null or not is_instance_valid(_disguise):
		_disguise = get_tree().get_first_node_in_group("player_disguise")
	if _clout == null or not is_instance_valid(_clout):
		_clout = get_tree().get_first_node_in_group("social_clout")


## True if any living officer is within range and has an unobstructed sightline
## (a ray masked to world geometry that reaches the player without being blocked).
func _seen_by_police() -> bool:
	if _player == null:
		return false
	var eye := _player.global_position + Vector3.UP * eye_height
	var space := _player.get_world_3d().direct_space_state
	for cop in get_tree().get_nodes_in_group("police"):
		var officer := cop as Node3D
		if officer == null:
			continue
		if officer.has_method("is_dead") and officer.is_dead():
			continue
		var from := officer.global_position + Vector3.UP * eye_height
		if from.distance_to(eye) > sight_radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, eye, 1)
		if space.intersect_ray(query).is_empty():
			return true
	return false
