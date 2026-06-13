class_name GangTerritoryController
extends Node
## Owns the player's ONE GangTerritory — the turf map and the player's influence in
## each district. Self-wires by group ("gang_territory") so every TurfZone feeds the
## SAME map: capture districts one at a time and track total control. Drives the
## tested GangTerritory model (tests/unit/test_gang_territory.gd); the only scene
## contact is the group registration, so it verifies in a mock tree
## (tests/turf_zone_probe.gd).
##
## turf_captured is the single hook a RivalRetaliation feed reads — taking a rival's
## turf should earn their grudge (provoke the dispossessed owner).

signal turf_captured(district_id: String, from_owner: String)

var _territory: GangTerritory


func _ready() -> void:
	_territory = GangTerritory.new()
	add_to_group("gang_territory")


## The shared turf map a zone captures into (districts + the player's influence).
func territory() -> GangTerritory:
	return _territory


## Fraction (0..1) of all districts the player controls, for a HUD readout.
func controlled_fraction() -> float:
	return _territory.controlled_fraction() if _territory != null else 0.0


## Current owner of a district ("" if unknown / not ready).
func owner_of(district_id: String) -> String:
	return _territory.owner_of(district_id) if _territory != null else ""


## Relay a capture so one place (this controller) is the subscribe point for the
## HUD / RivalRetaliation. Called by a TurfZone when it flips a district.
func report_capture(district_id: String, from_owner: String) -> void:
	turf_captured.emit(district_id, from_owner)
