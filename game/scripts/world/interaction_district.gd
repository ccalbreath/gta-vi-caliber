class_name InteractionDistrict
extends Node3D
## Drops the WHOLE player-services interaction layer into a scene as one node. Add a
## single InteractionDistrict and you get: the controllers that hold shared player
## state (disguise wardrobe, contraband stash, gang turf, stock portfolio) AND the
## walk-up activities that drive them (clothing store, slot machine, black market,
## hit-contract board, stock terminal, turf zone) — all live, grouped, and enterable
## with no per-activity plumbing. The integrator places this where the services
## plaza should sit; the player walks the ring and every loop is reachable.
##
## Builds its children in _ready (cf. FloridaBackdrop), each activity an Area3D with
## a box trigger fanned out on a ring of radius `spread`. Controllers are spawned
## ONLY if their group isn't already present (deferred a frame so any scene-placed
## owner wins), so it composes with whatever a scene already wired — no duplicate
## market / disguise owners. Verified structurally in
## tests/interaction_district_probe.gd.

## Half-extent of each activity's square trigger zone, in metres.
@export var zone_size: float = 3.0
## Height of each trigger box (so the player rig overlaps it).
@export var zone_height: float = 3.0
## Distance from the district centre each activity is placed.
@export var spread: float = 7.0
## Which GangTerritory district this plaza's turf zone captures. MUST be unique per
## placed district — two plazas sharing one id accrue influence at double rate (the
## TurfZone warns about it).
@export var turf_district: String = "downtown"


func _ready() -> void:
	add_to_group("interaction_district")
	_build_activities()
	# Spawn missing controllers next frame, after any scene-placed owners have
	# registered their groups (so we never duplicate a market / disguise owner).
	call_deferred("_ensure_controllers")


func _build_activities() -> void:
	var ring := _ring_positions()
	_place_area(ClothingStore.new(), ring[0])
	_place_area(SlotMachine.new(), ring[1])
	_place_area(BlackMarketStall.new(), ring[2])
	_place_area(StockTerminal.new(), ring[3])
	var turf := TurfZone.new()
	turf.district_id = turf_district
	_place_area(turf, ring[4])
	_place_hit_board(ring[5])


## Ring of six local positions around the centre — fixed unit hex corners scaled by
## `spread` (hand-tabulated so the build stays trig-free and deterministic).
func _ring_positions() -> Array:
	var unit := [
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.5, 0.0, 0.866),
		Vector3(-0.5, 0.0, 0.866),
		Vector3(-1.0, 0.0, 0.0),
		Vector3(-0.5, 0.0, -0.866),
		Vector3(0.5, 0.0, -0.866),
	]
	var out: Array = []
	for v: Vector3 in unit:
		out.append(v * spread)
	return out


## Add an Area3D activity at a local position with a box trigger so the player can
## enter it.
func _place_area(area: Area3D, local_pos: Vector3) -> void:
	area.add_child(_make_trigger())
	# Position BEFORE entering the tree so the zone never exists at the origin for a
	# frame (which could fire a body_entered at the wrong spot in a live scene).
	area.position = local_pos
	add_child(area)


## The hit-contract board is a Node3D with two named Area3D zones (Board, Target);
## offset the Target so it's a short walk from the Board (the MIN_TRAVEL gate).
func _place_hit_board(local_pos: Vector3) -> void:
	var board := HitContractBoard.new()
	var giver := Area3D.new()
	giver.name = "Board"
	giver.add_child(_make_trigger())
	board.add_child(giver)
	var target := Area3D.new()
	target.name = "Target"
	target.add_child(_make_trigger())
	target.position = Vector3(0.0, 0.0, zone_size * 3.0)
	board.add_child(target)
	board.position = local_pos
	add_child(board)


## A CollisionShape3D + BoxShape3D trigger sized zone_size x zone_height x zone_size.
func _make_trigger() -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(zone_size, zone_height, zone_size)
	shape.shape = box
	return shape


## Spawn each shared-state controller only if nothing already owns its group.
func _ensure_controllers() -> void:
	if not is_inside_tree():
		return
	_ensure_controller("player_disguise", DisguiseController.new())
	_ensure_controller("contraband", ContrabandController.new())
	_ensure_controller("gang_territory", GangTerritoryController.new())
	_ensure_controller("stock_market", MarketEventCoordinator.new())
	# After gang_territory so it can bind to that turf source (it also self-binds).
	_ensure_controller("rival_retaliation", RivalRetaliationController.new())
	# After rival_retaliation so it can bind to its strikes (it also self-binds).
	_ensure_controller("player_bounty", PlayerBountyController.new())


func _ensure_controller(group_name: String, node: Node) -> void:
	# add_child() runs _ready() synchronously, which registers the owner's group
	# before the next district's deferred _ensure_controllers in the same flush — so
	# two districts added the same frame still end up with ONE owner per group.
	if get_tree().get_first_node_in_group(group_name) != null:
		node.free()  # never parented (no _ready, no group) — safe discard, no leak
		return
	add_child(node)
