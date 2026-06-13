class_name DisguiseController
extends Node
## Owns the player's ONE live Disguise AND their Wardrobe — the single source of
## truth for what the player owns, what they're wearing, and the appearance the
## cops try to match against the description they have on file. Self-wires by group
## ("player_disguise") so other systems find it without scene plumbing: a
## ClothingStore sells into wardrobe() and calls refresh_disguise() to re-skin the
## look, a police-sighting hook calls log_sighting() when the player is clearly
## spotted, and a wanted-evasion feed reads evasion_speedup() so a well-disguised
## player shakes a search faster.
##
## The Wardrobe lives here (not on each store) so ownership persists across every
## store the player visits — you buy a jacket once, then it's free to wear anywhere.
##
## Drives the pure, tested Wardrobe + Disguise models. The only scene contact is the
## group registration, so it verifies in a mock tree (tests/clothing_store_probe.gd).

signal look_changed(slot: String, value: String)
signal sighting_logged

var _disguise: Disguise
var _wardrobe: Wardrobe


func _ready() -> void:
	_disguise = Disguise.new()
	_wardrobe = Wardrobe.new()
	add_to_group("player_disguise")


## The player's wardrobe (owned + currently-worn clothing). A clothing store sells
## into this shared instance, so ownership carries across stores.
func wardrobe() -> Wardrobe:
	return _wardrobe


## Re-skin the live Disguise from whatever the wardrobe currently has worn — call
## after a store changes the player's clothes.
func refresh_disguise() -> void:
	if _wardrobe != null:
		apply_looks(_wardrobe.worn_looks())


## Change one appearance slot on the live look (unknown slots ignored).
func set_appearance(slot: String, value: String) -> void:
	if _disguise == null:
		return
	_disguise.set_appearance(slot, value)
	look_changed.emit(slot, _disguise.current(slot))


## Apply a whole {slot: look} set at once — exactly what Wardrobe.worn_looks()
## returns, so a clothing store can re-skin the player in one call.
func apply_looks(looks: Dictionary) -> void:
	for slot: Variant in looks:
		set_appearance(str(slot), str(looks[slot]))


## Police memorise the player's current look as the description to hunt. Call when
## the player is clearly seen committing a crime.
func log_sighting() -> void:
	if _disguise == null:
		return
	_disguise.log_sighting()
	sighting_logged.emit()


## The player's current value for a slot ("" if unknown / not ready).
func current(slot: String) -> String:
	return _disguise.current(slot) if _disguise != null else ""


## How recognizable the player still is versus the logged description, [0, 1].
## 0.0 when police have no description on file.
func recognition() -> float:
	return _disguise.recognition() if _disguise != null else 0.0


## True once police have a description to hunt.
func has_description() -> bool:
	return _disguise != null and _disguise.has_description()


## Multiplier a wanted-evasion feed applies to its search delta: 1.0 when fully
## recognized, up to Disguise.MAX_EVASION_SPEEDUP when fully disguised. Lets the
## "go cold" countdown drain faster the less you look like their description.
func evasion_speedup() -> float:
	return _disguise.evasion_speedup() if _disguise != null else 1.0


## How many appearance slots differ from the logged description (0 when none on
## file) — a "you changed N things about your look" count for HUD feedback.
func changed_slots() -> int:
	return _disguise.changed_slots() if _disguise != null else 0


## Police lose the trail (the player went cold / respawned): clear the description
## so the next sighting starts fresh.
func clear_description() -> void:
	if _disguise != null:
		_disguise.reset_to_clean()
