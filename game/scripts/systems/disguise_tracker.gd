class_name DisguiseTracker
extends Node
## Live player-owned bridge for the pure Disguise model.
##
## WardrobeShop pushes worn looks here; wanted/evasion systems can read the same
## current appearance and recognition speedup by group (`player_disguise`). Keeping
## this on the player avoids hiding disguise state inside a storefront.

var disguise: Disguise


func _init() -> void:
	disguise = Disguise.new()


func _ready() -> void:
	add_to_group("player_disguise")


func apply_looks(looks: Dictionary) -> void:
	for slot: Variant in looks:
		set_appearance(String(slot), String(looks[slot]))


func set_appearance(slot: String, value: String) -> void:
	disguise.set_appearance(slot, value)


func current(slot: String) -> String:
	return disguise.current(slot)


func log_sighting() -> void:
	disguise.log_sighting()


func has_description() -> bool:
	return disguise.has_description()


func recognition() -> float:
	return disguise.recognition()


func evasion_speedup() -> float:
	return disguise.evasion_speedup()


func changed_slots() -> int:
	return disguise.changed_slots()


func reset_to_clean() -> void:
	disguise.reset_to_clean()
