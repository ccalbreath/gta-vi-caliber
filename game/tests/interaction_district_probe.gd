extends SceneTree
## Structural probe for InteractionDistrict — proves that dropping ONE node into a
## scene assembles the entire player-services interaction layer: all four shared
## controllers and all six walk-up activities, each grouped and each with a real
## collision trigger so the player can enter it. Adds TWO districts in the SAME
## frame to prove the controllers are spawned exactly once (a scene must have one
## disguise/contraband/turf/market owner) while each district still builds its own
## activities. Structural only — no physics. Run:
##   godot --headless --path game --script res://tests/interaction_district_probe.gd

const SETTLE_FRAMES: int = 4
const CONTROLLERS: Array = [
	"player_disguise", "contraband", "gang_territory", "stock_market", "rival_retaliation"
]
const ACTIVITIES: Array = [
	"clothing_store", "slot_machine", "black_market", "stock_terminal", "turf_zone"
]

var _frames: int = 0


func _initialize() -> void:
	# Two plazas added the same frame — the controller dedup must survive the race.
	var a := InteractionDistrict.new()
	a.turf_district = "downtown"
	root.add_child(a)
	var b := InteractionDistrict.new()
	b.turf_district = "beach"
	root.add_child(b)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	return _assert_assembled()


func _count(group_name: String) -> int:
	return get_nodes_in_group(group_name).size()


# An Area3D is enterable only if it has a CollisionShape3D child with a real shape.
func _has_trigger(node: Node) -> bool:
	if node == null:
		return false
	for child: Node in node.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			return true
	return false


func _assert_assembled() -> bool:
	# Each shared controller spawned exactly once despite two same-frame districts.
	for group_name: String in CONTROLLERS:
		if _count(group_name) != 1:
			return _fail("controller '%s' has %d (want 1)" % [group_name, _count(group_name)])

	# Each walk-up activity present, enterable, and built by BOTH districts (==2).
	for group_name: String in ACTIVITIES:
		if not _has_trigger(get_first_node_in_group(group_name)):
			return _fail("activity '%s' missing or has no collision trigger" % group_name)
		if _count(group_name) != 2:
			return _fail(
				(
					"activity '%s' count %d (want 2, one per district)"
					% [group_name, _count(group_name)]
				)
			)

	return _assert_hit_board()


func _assert_hit_board() -> bool:
	if _count("hit_contract_board") != 2:
		return _fail("hit board count %d (want 2)" % _count("hit_contract_board"))
	var board := get_first_node_in_group("hit_contract_board")
	if not _has_trigger(board.get_node_or_null("Board")):
		return _fail("hit board Board zone has no trigger")
	if not _has_trigger(board.get_node_or_null("Target")):
		return _fail("hit board Target zone has no trigger")
	return _pass()


func _pass() -> bool:
	print(
		"interaction district probe: OK (4 controllers once + 6 activities/district, all enterable)"
	)
	quit(0)
	return true


func _fail(message: String) -> bool:
	push_error("interaction district probe FAIL :: %s" % message)
	print("interaction district probe: FAIL — %s" % message)
	quit(1)
	return true
